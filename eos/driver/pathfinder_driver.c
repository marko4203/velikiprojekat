/*
 * pathfinder_driver.c
 *
 * Uredjaji koje drajver kreira:
 *   /dev/pathfinder       (minor 0)  AXI-Lite registri IP-ja
 *        write:  "sx,sy,ex,ey"   -> upis START/END koordinata + pokretanje pretrage
 *        read :  blokira dok IP ne generise prekid, vraca "1\n"; sledeci read vraca 0 (EOF)
 *                po istom endRead principu kao led_read u Vezbi 9
 *                (O_NONBLOCK: odmah vraca trenutni done status)
 *        fasync: SIGIO korisnickom procesu kada stigne prekid 
 *
 *   /dev/pathfinder_bram  (minor 1)  grid 100x100 node-ova (24-bit, u u32)
 *        ponasa se kao fajl od 40000 bajtova: node[i] je na bajt ofsetu 4*i,
 *        i = x*100 + y. Drajver prevodi "flat" indeks u fizicku BRAM adresu
 *        (4 banke x 2500, CPU strana ima korak 4096 reci po banci).
 *
 * Mapa AXI-Lite registara (pathfinder_axi_slave_lite_v1_0_S00_AXI.vhd):
 *   0x00 START   [13:7]=x  [6:0]=y      R/W
 *   0x04 END     [13:7]=x  [6:0]=y      R/W
 *   0x08 CTRL    bilo koji upis = start FSM-a   (citanje uvek 0)
 *   0x0C STATUS  bit0 = done   (posle HW izmene: sticky, W1C; bit1 = busy, bit2 = solved)
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/version.h>
#include <linux/fs.h>
#include <linux/cdev.h>
#include <linux/device.h>
#include <linux/kdev_t.h>
#include <linux/types.h>
#include <linux/errno.h>
#include <linux/uaccess.h>
#include <linux/io.h>
#include <linux/slab.h>
#include <linux/ioport.h>
#include <linux/platform_device.h>
#include <linux/of.h>
#include <linux/of_device.h>
#include <linux/interrupt.h>
#include <linux/wait.h>
#include <linux/sched.h>
#include <linux/jiffies.h>
#include <linux/string.h>

MODULE_AUTHOR("EOS projekat - pathfinder");
MODULE_DESCRIPTION("Platform drajver za pathfinder_axi IP (A* / greedy pretraga na 100x100 gridu)");
MODULE_LICENSE("Dual BSD/GPL");
MODULE_ALIAS("custom:pathfinder");

/* ------------------------------------------------------------------------- */
/* Konstante                                                                  */
/* ------------------------------------------------------------------------- */

#define DRIVER_NAME      "pathfinder_driver"
#define DEV_CORE_NAME    "pathfinder"        /* = compatible string u stablu uredjaja */
#define DEV_BRAM_NAME    "pathfinder_bram"   /* = compatible string u stablu uredjaja */

#define MINOR_CORE       0
#define MINOR_BRAM       1
#define NUM_MINORS       2

/* AXI-Lite registri */
#define PF_REG_START     0x00
#define PF_REG_END       0x04
#define PF_REG_CTRL      0x08
#define PF_REG_STATUS    0x0C

#define PF_STATUS_DONE   0x1
#define PF_STATUS_BUSY   0x2
#define PF_STATUS_SOLVED 0x4

#define PF_COORD_BITS    7                   /* x i y su 7-bitni (0..99) */
#define PF_COORD_MASK    0x7F

/* Geometrija grida i BRAM-a */
#define GRID_SIZE        100
#define GRID_NODES       (GRID_SIZE * GRID_SIZE)      /* 10000 node-ova          */
#define BRAM_DEPTH       2500                          /* node-ova po banci (IP)  */
#define BANK_STRIDE      4096                          /* reci po banci (CPU)     */
#define NODE_MASK        0x00FFFFFF                    /* node je 24-bitni        */
#define BRAM_SPAN        (GRID_NODES * 4)              /* "velicina fajla" u B    */

#define WAIT_TIMEOUT_MS  10000
#define BUFF_SIZE        64

/* ------------------------------------------------------------------------- */
/* Strukture i globalne promenljive                                          */
/* ------------------------------------------------------------------------- */

struct pf_dev {
	unsigned long mem_start;      /* pocetna fizicka adresa (iz stabla uredjaja)  */
	unsigned long mem_end;        /* krajnja fizicka adresa                        */
	void __iomem *base_addr;      /* virtuelna adresa posle ioremap               */
	int irq_num;                  /* broj prekidne linije (samo za core)          */
};

static struct pf_dev *pf_core;    /* AXI-Lite deo IP-ja      */
static struct pf_dev *pf_bram;    /* AXI BRAM Controller     */

static dev_t         pf_dev_id;
static struct class *pf_class;
static struct cdev  *pf_cdev;

static DECLARE_WAIT_QUEUE_HEAD(pf_wq);
static int pf_done;                          /* 1 = stigao prekid od poslednje pretrage */
static int endRead;                          /* kao u Vezbi 9: drugi uzastopni read vraca 0 */
static struct fasync_struct *pf_async;

/* platform_driver.remove vraca int do kernela 6.10, a void od 6.11 */
#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 11, 0)
#define PF_REMOVE_RET   void
#define PF_REMOVE_RETURN(x) return
#else
#define PF_REMOVE_RET   int
#define PF_REMOVE_RETURN(x) return (x)
#endif

/* ------------------------------------------------------------------------- */
/* Pomocne funkcije                                                           */
/* ------------------------------------------------------------------------- */

/*
 * Prevodjenje "flat" indeksa node-a (x*100 + y) u bajt ofset unutar
 * adresnog prostora AXI BRAM Controller-a.
 *
 *   IP strana  (bram_router.vhd):            banka = idx / 2500, sub = idx % 2500
 *   CPU strana (bram_controller_router.vhd): banka = ctrl_addr[13:12], sub = ctrl_addr[11:0]
 *
 * => rec = banka*4096 + sub,  bajt ofset = 4 * rec
 *    (banka 0: 0x0000.., banka 1: 0x4000.., banka 2: 0x8000.., banka 3: 0xC000..)
 */
static inline u32 pf_node_offset(u32 idx)
{
	u32 bank = idx / BRAM_DEPTH;
	u32 sub  = idx % BRAM_DEPTH;

	return (bank * BANK_STRIDE + sub) * 4;
}

/* ------------------------------------------------------------------------- */
/* Prekidna rutina                                                            */
/* ------------------------------------------------------------------------- */

static irqreturn_t pf_isr(int irq, void *dev_id)
{
	u32 status;

	status = ioread32(pf_core->base_addr + PF_REG_STATUS);

	/*
	 * Brisanje prekida upisom jedinice u bit 0 STATUS registra (W1C, isti
	 * princip kao T0INT bit kod AXI Timer-a iz Vezbe 10). Ovo je neophodno
	 * ako je uradjena HW izmena sa "sticky" (level) prekidom. Na originalnom
	 * hardveru (impulsni irq) upis u ofset 0x0C je no-op, pa ne smeta.
	 */
	iowrite32(status | PF_STATUS_DONE, pf_core->base_addr + PF_REG_STATUS);

	pf_done = 1;
	wake_up_interruptible(&pf_wq);                 /* budi blokirani read()   */
	kill_fasync(&pf_async, SIGIO, POLL_IN);

	printk(KERN_INFO "pathfinder_isr: pretraga zavrsena (status=0x%x)\n", status);

	return IRQ_HANDLED;
}

/* ------------------------------------------------------------------------- */
/* Probe / remove                                                             */
/* ------------------------------------------------------------------------- */

static int pf_probe(struct platform_device *pdev)
{
	struct resource *r_mem;
	struct pf_dev *d;
	int is_core;
	int rc = 0;

	if (of_device_is_compatible(pdev->dev.of_node, DEV_CORE_NAME))
		is_core = 1;
	else if (of_device_is_compatible(pdev->dev.of_node, DEV_BRAM_NAME))
		is_core = 0;
	else
		return -ENODEV;

	/* Fizicke adrese registara iz stabla uredjaja (kao led_probe, Vezba 9) */
	r_mem = platform_get_resource(pdev, IORESOURCE_MEM, 0);
	if (!r_mem) {
		printk(KERN_ALERT "pathfinder_probe: Failed to get reg resource\n");
		return -ENODEV;
	}

	d = (struct pf_dev *) kmalloc(sizeof(struct pf_dev), GFP_KERNEL);
	if (!d) {
		printk(KERN_ALERT "pathfinder_probe: Could not allocate memory\n");
		return -ENOMEM;
	}

	d->mem_start = r_mem->start;
	d->mem_end   = r_mem->end;
	d->base_addr = NULL;
	d->irq_num   = -1;

	/* Rezervacija opsega fizickih adresa za ovaj drajver */
	if (!request_mem_region(d->mem_start, d->mem_end - d->mem_start + 1, DRIVER_NAME)) {
		printk(KERN_ALERT "pathfinder_probe: Couldn't lock memory region at 0x%lx\n", d->mem_start);
		rc = -EBUSY;
		goto error1;
	}

	/* Mapiranje fizickih u virtuelne adrese */
	d->base_addr = ioremap(d->mem_start, d->mem_end - d->mem_start + 1);
	if (!d->base_addr) {
		printk(KERN_ALERT "pathfinder_probe: Could not allocate iomem\n");
		rc = -EIO;
		goto error2;
	}

	if (is_core) {
		/* Broj prekidne linije iz stabla uredjaja (kao timer_probe, Vezba 10).
		 * platform_get_irq vraca NEGATIVNU vrednost na gresku, ne 0.          */
		d->irq_num = platform_get_irq(pdev, 0);
		if (d->irq_num < 0) {
			printk(KERN_ALERT "pathfinder_probe: Failed to get irq resource\n");
			rc = -ENODEV;
			goto error3;
		}

		pf_core = d;   /* mora pre request_irq - ISR koristi pf_core */

		if (request_irq(d->irq_num, pf_isr, 0, DEV_CORE_NAME, d)) {
			printk(KERN_ERR "pathfinder_probe: Cannot register IRQ %d\n", d->irq_num);
			pf_core = NULL;
			rc = -EIO;
			goto error3;
		}
		printk(KERN_INFO "pathfinder_probe: Registered IRQ %d\n", d->irq_num);
		printk(KERN_NOTICE "pathfinder_probe: pathfinder platform driver registered (regs @ 0x%lx)\n", d->mem_start);
	} else {
		pf_bram = d;
		printk(KERN_NOTICE "pathfinder_probe: pathfinder_bram platform driver registered (BRAM @ 0x%lx, %lu B)\n",
		       d->mem_start, d->mem_end - d->mem_start + 1);
	}

	return 0;

error3:
	iounmap(d->base_addr);
error2:
	release_mem_region(d->mem_start, d->mem_end - d->mem_start + 1);
error1:
	kfree(d);
	return rc;
}

static PF_REMOVE_RET pf_remove(struct platform_device *pdev)
{
	struct pf_dev *d;

	/* Isti kriterijum kao u probe: koji od dva uredjaja se uklanja */
	if (of_device_is_compatible(pdev->dev.of_node, DEV_CORE_NAME) && pf_core) {
		d = pf_core;
		printk(KERN_ALERT "pathfinder_remove: pathfinder platform driver removed\n");
		iowrite32(PF_STATUS_DONE, d->base_addr + PF_REG_STATUS);   /* obrisi eventualni prekid (kao iowrite32(0) u Vezbi 9) */
		free_irq(d->irq_num, d);
		pf_core = NULL;
	} else if (of_device_is_compatible(pdev->dev.of_node, DEV_BRAM_NAME) && pf_bram) {
		d = pf_bram;
		printk(KERN_ALERT "pathfinder_remove: pathfinder_bram platform driver removed\n");
		pf_bram = NULL;
	} else {
		PF_REMOVE_RETURN(0);
	}

	iounmap(d->base_addr);
	release_mem_region(d->mem_start, d->mem_end - d->mem_start + 1);
	kfree(d);
	PF_REMOVE_RETURN(0);
}

/* ------------------------------------------------------------------------- */
/* File operacije: /dev/pathfinder (core)                                     */
/* ------------------------------------------------------------------------- */

static ssize_t pf_core_write(struct file *f, const char __user *buf, size_t len, loff_t *off)
{
	char buff[BUFF_SIZE];
	int sx, sy, ex, ey;

	if (!pf_core)
		return -ENODEV;
	if (len == 0 || len >= BUFF_SIZE)
		return -EINVAL;
	if (copy_from_user(buff, buf, len))
		return -EFAULT;
	buff[len] = '\0';

	/* Isti princip kao timer_write (Vezba 10): sscanf, pa provera broja parametara.
	 * Pogresan format se prijavljuje u dmesg, a poziv vraca length (kao led_write u Vezbi 9). */
	if (sscanf(buff, "%d,%d,%d,%d", &sx, &sy, &ex, &ey) != 4) {
		printk(KERN_WARNING "pathfinder_write: Wrong command format, expected sx,sy,ex,ey\n");
		return len;
	}
	if (sx < 0 || sx >= GRID_SIZE || sy < 0 || sy >= GRID_SIZE ||
	    ex < 0 || ex >= GRID_SIZE || ey < 0 || ey >= GRID_SIZE) {
		printk(KERN_WARNING "pathfinder_write: coordinates must be in range 0..%d\n", GRID_SIZE - 1);
		return len;
	}

	pf_done = 0;                                   /* pre starta, zbog trke sa ISR-om */
	endRead = 0;                                   /* nova pretraga -> sledeci read ceka i vraca rezultat */

	iowrite32((sx << PF_COORD_BITS) | sy, pf_core->base_addr + PF_REG_START);
	iowrite32((ex << PF_COORD_BITS) | ey, pf_core->base_addr + PF_REG_END);
	iowrite32(1, pf_core->base_addr + PF_REG_CTRL);   /* start (vrednost nije bitna) */

	printk(KERN_INFO "pathfinder_write: start (%d,%d) -> end (%d,%d)\n", sx, sy, ex, ey);
	return len;
}

static ssize_t pf_core_read(struct file *f, char __user *buf, size_t len, loff_t *off)
{
	char buff[BUFF_SIZE];
	long rc;
	int n;

	if (!pf_core)
		return -ENODEV;

	/* endRead kao u led_read (Vezba 9): drugi uzastopni read vraca 0 (EOF),
	 * pa `cat /dev/pathfinder` zavrsava posle jedne linije.                */
	if (endRead) {
		endRead = 0;
		return 0;
	}

	if (!(f->f_flags & O_NONBLOCK)) {
		rc = wait_event_interruptible_timeout(pf_wq, pf_done != 0,
						      msecs_to_jiffies(WAIT_TIMEOUT_MS));
		if (rc == 0) {
			printk(KERN_WARNING "pathfinder_read: timeout - prekid nije stigao\n");
			return -ETIMEDOUT;
		}
		if (rc < 0)
			return rc;                     /* -ERESTARTSYS (Ctrl-C) */
	}

	n = scnprintf(buff, BUFF_SIZE, "%d\n", pf_done);
	if (n > len)
		n = len;
	if (copy_to_user(buf, buff, n))
		return -EFAULT;

	endRead = 1;
	return n;
}

static loff_t pf_core_llseek(struct file *f, loff_t off, int whence)
{
	/* /dev/pathfinder nema pozicije (endRead semantika) - lseek je no-op */
	return 0;
}

/* ------------------------------------------------------------------------- */
/* File operacije: /dev/pathfinder_bram                                       */
/* ------------------------------------------------------------------------- */

static ssize_t pf_bram_write(struct file *f, const char __user *buf, size_t len, loff_t *off)
{
	u32 chunk[128];   /* 512 B na steku - dovoljno malo za kernel stek */
	size_t done = 0;
	u32 idx;

	if (!pf_bram)
		return -ENODEV;
	if (*off < 0 || *off >= BRAM_SPAN)
		return -ENOSPC;
	if ((*off & 3) || (len & 3)) {
		printk(KERN_WARNING "pathfinder_bram_write: ofset i duzina moraju biti umnozak 4 (jedan node = u32)\n");
		return -EINVAL;
	}
	if (len > BRAM_SPAN - *off)
		len = BRAM_SPAN - *off;

	idx = (u32)(*off / 4);

	while (done < len) {
		size_t n = len - done;
		size_t i;

		if (n > sizeof(chunk))
			n = sizeof(chunk);
		if (copy_from_user(chunk, buf + done, n))
			return done ? (ssize_t)done : -EFAULT;

		for (i = 0; i < n / 4; i++, idx++)
			iowrite32(chunk[i] & NODE_MASK, pf_bram->base_addr + pf_node_offset(idx));

		done += n;
	}

	*off += done;
	return done;
}

static ssize_t pf_bram_read(struct file *f, char __user *buf, size_t len, loff_t *off)
{
	u32 chunk[128];   /* 512 B na steku - dovoljno malo za kernel stek */
	size_t done = 0;
	u32 idx;

	if (!pf_bram)
		return -ENODEV;
	if (*off < 0 || *off >= BRAM_SPAN)
		return 0;                                  /* EOF */
	if ((*off & 3) || (len & 3))
		return -EINVAL;
	if (len > BRAM_SPAN - *off)
		len = BRAM_SPAN - *off;

	idx = (u32)(*off / 4);

	while (done < len) {
		size_t n = len - done;
		size_t i;

		if (n > sizeof(chunk))
			n = sizeof(chunk);

		for (i = 0; i < n / 4; i++, idx++)
			chunk[i] = ioread32(pf_bram->base_addr + pf_node_offset(idx)) & NODE_MASK;

		if (copy_to_user(buf + done, chunk, n))
			return done ? (ssize_t)done : -EFAULT;

		done += n;
	}

	*off += done;
	return done;
}

static loff_t pf_bram_llseek(struct file *f, loff_t off, int whence)
{
	return fixed_size_llseek(f, off, whence, BRAM_SPAN);
}

/* ------------------------------------------------------------------------- */
/* Zajednicke file operacije - dispatch po minor broju                        */
/* ------------------------------------------------------------------------- */

static int pf_fasync(int fd, struct file *file, int mode)
{
	return fasync_helper(fd, file, mode, &pf_async);
}

static int pf_open(struct inode *i, struct file *f)
{
	return 0;
}

static int pf_release(struct inode *i, struct file *f)
{
	pf_fasync(-1, f, 0);   /* ukloni proces iz fasync liste ako je bio prijavljen */
	return 0;
}

static ssize_t pf_read(struct file *f, char __user *buf, size_t len, loff_t *off)
{
	switch (iminor(file_inode(f))) {
	case MINOR_CORE: return pf_core_read(f, buf, len, off);
	case MINOR_BRAM: return pf_bram_read(f, buf, len, off);
	default:         return -ENODEV;
	}
}

static ssize_t pf_write(struct file *f, const char __user *buf, size_t len, loff_t *off)
{
	switch (iminor(file_inode(f))) {
	case MINOR_CORE: return pf_core_write(f, buf, len, off);
	case MINOR_BRAM: return pf_bram_write(f, buf, len, off);
	default:         return -ENODEV;
	}
}

static loff_t pf_llseek(struct file *f, loff_t off, int whence)
{
	switch (iminor(file_inode(f))) {
	case MINOR_CORE: return pf_core_llseek(f, off, whence);
	case MINOR_BRAM: return pf_bram_llseek(f, off, whence);
	default:         return -ENODEV;
	}
}

static const struct file_operations pf_fops = {
	.owner   = THIS_MODULE,
	.open    = pf_open,
	.release = pf_release,
	.read    = pf_read,
	.write   = pf_write,
	.llseek  = pf_llseek,
	.fasync  = pf_fasync,
};

/* ------------------------------------------------------------------------- */
/* Platform drajver - povezivanje sa stablom uredjaja                          */
/* ------------------------------------------------------------------------- */

static const struct of_device_id pf_of_match[] = {
	{ .compatible = DEV_CORE_NAME, },
	{ .compatible = DEV_BRAM_NAME, },
	{ /* kraj liste */ },
};
MODULE_DEVICE_TABLE(of, pf_of_match);

static struct platform_driver pf_driver = {
	.driver = {
		.name           = DRIVER_NAME,
		.owner          = THIS_MODULE,
		.of_match_table = pf_of_match,
	},
	.probe  = pf_probe,
	.remove = pf_remove,
};

/* ------------------------------------------------------------------------- */
/* Init / exit                                                                */
/* ------------------------------------------------------------------------- */

static int __init pf_init(void)
{
	int rc;
	struct device *dev;

	printk(KERN_INFO "pathfinder_init: insmod\n");

	rc = alloc_chrdev_region(&pf_dev_id, 0, NUM_MINORS, "pathfinder_region");
	if (rc < 0) {
		printk(KERN_ERR "pathfinder_init: alloc_chrdev_region neuspesan\n");
		return rc;
	}

#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 4, 0)
	pf_class = class_create("pathfinder_class");
#else
	pf_class = class_create(THIS_MODULE, "pathfinder_class");
#endif
	if (IS_ERR(pf_class)) {
		printk(KERN_ERR "pathfinder_init: class_create neuspesan\n");
		rc = PTR_ERR(pf_class);
		goto fail_region;
	}

	dev = device_create(pf_class, NULL, MKDEV(MAJOR(pf_dev_id), MINOR_CORE), NULL, DEV_CORE_NAME);
	if (IS_ERR(dev)) {
		rc = PTR_ERR(dev);
		goto fail_class;
	}
	dev = device_create(pf_class, NULL, MKDEV(MAJOR(pf_dev_id), MINOR_BRAM), NULL, DEV_BRAM_NAME);
	if (IS_ERR(dev)) {
		rc = PTR_ERR(dev);
		goto fail_dev0;
	}

	pf_cdev = cdev_alloc();
	if (!pf_cdev) {
		rc = -ENOMEM;
		goto fail_dev1;
	}
	pf_cdev->ops   = &pf_fops;
	pf_cdev->owner = THIS_MODULE;

	rc = cdev_add(pf_cdev, pf_dev_id, NUM_MINORS);
	if (rc) {
		printk(KERN_ERR "pathfinder_init: cdev_add neuspesan\n");
		goto fail_cdev;
	}

	rc = platform_driver_register(&pf_driver);
	if (rc) {
		printk(KERN_ERR "pathfinder_init: platform_driver_register neuspesan\n");
		goto fail_cdev;
	}

	printk(KERN_INFO "pathfinder_init: /dev/%s i /dev/%s kreirani (major %d)\n",
	       DEV_CORE_NAME, DEV_BRAM_NAME, MAJOR(pf_dev_id));
	return 0;

fail_cdev:
	cdev_del(pf_cdev);      /* bezbedno i ako cdev_add nije uspeo */
fail_dev1:
	device_destroy(pf_class, MKDEV(MAJOR(pf_dev_id), MINOR_BRAM));
fail_dev0:
	device_destroy(pf_class, MKDEV(MAJOR(pf_dev_id), MINOR_CORE));
fail_class:
	class_destroy(pf_class);
fail_region:
	unregister_chrdev_region(pf_dev_id, NUM_MINORS);
	return rc;
}

static void __exit pf_exit(void)
{
	printk(KERN_INFO "pathfinder_exit: rmmod\n");

	platform_driver_unregister(&pf_driver);        /* poziva pf_remove za oba uredjaja */
	cdev_del(pf_cdev);
	device_destroy(pf_class, MKDEV(MAJOR(pf_dev_id), MINOR_BRAM));
	device_destroy(pf_class, MKDEV(MAJOR(pf_dev_id), MINOR_CORE));
	class_destroy(pf_class);
	unregister_chrdev_region(pf_dev_id, NUM_MINORS);
}

module_init(pf_init);
module_exit(pf_exit);
