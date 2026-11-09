/*
 * pathfinder_app.c
 *
 *   ./pathfinder_app               - ugradjeni demo lavirint, izvrsava se na HW
 *   ./pathfinder_app maze.txt      - lavirint iz fajla (100 linija x 100 znakova: . # S E)
 *   ./pathfinder_app --sim [maze]  - bez ploce: softverski model IP FSM-a (za test logike na PC-u)
 *
 * Tok rada na ploci:
 *   1. napravi grid od 100x100 node-ova (24-bit format iz pathfinder_ip.vhd)
 *   2. upisi ceo grid u /dev/pathfinder_bram jednim pwrite() pozivom
 *   3. upisi "sx,sy,ex,ey" u /dev/pathfinder  -> drajver upisuje START/END registre i startuje FSM
 *   4. read() na /dev/pathfinder blokira dok IP ne generise prekid
 *   5. procitaj grid nazad iz BRAM-a i rekonstruisi putanju prateci parent pokazivace od END ka START
 *
 * Konvencija koordinata (kao u VHDL-u): x = red (vrsta), y = kolona, flat = x*100 + y.
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>

#define GRID        100
#define N_NODES     (GRID * GRID)

/* Node format: [23:15] dist (9b) | [14:8] parentX (7b) | [7:1] parentY (7b) | [0] visited */
#define DIST_SHIFT  15
#define PX_SHIFT    8
#define PY_SHIFT    1

#define VAL_PATH    0      /* neposecen prolaz - heuristika jos nije izracunata */
#define VAL_WALL    298
#define VAL_START   299
#define VAL_END     300
#define VAL_FINAL   301    /* obelezava CPU posle rekonstrukcije (IP ga ne koristi) */

#define DEV_CORE    "/dev/pathfinder"
#define DEV_BRAM    "/dev/pathfinder_bram"

static inline uint32_t node_dist(uint32_t n)    { return (n >> DIST_SHIFT) & 0x1FF; }
static inline uint32_t node_px(uint32_t n)      { return (n >> PX_SHIFT) & 0x7F; }
static inline uint32_t node_py(uint32_t n)      { return (n >> PY_SHIFT) & 0x7F; }
static inline uint32_t node_visited(uint32_t n) { return n & 1; }
static inline uint32_t make_node(uint32_t dist) { return (dist & 0x1FF) << DIST_SHIFT; }

/* ------------------------------------------------------------------------- */
/* Lavirint                                                                    */
/* ------------------------------------------------------------------------- */

static void demo_maze(uint32_t *g, int *sx, int *sy, int *ex, int *ey)
{
	int x, y;

	for (x = 0; x < N_NODES; x++)
		g[x] = make_node(VAL_PATH);

	/* vertikalni zidovi u kolonama 20,40,60,80 sa naizmenicnim prolazima -> "zmija" */
	for (y = 20; y < GRID; y += 20)
		for (x = 0; x < GRID; x++) {
			int gap_row = ((y / 20) % 2) ? GRID - 1 : 0;
			if (x != gap_row)
				g[x * GRID + y] = make_node(VAL_WALL);
		}

	*sx = 0;  *sy = 0;
	*ex = 99; *ey = 99;
	g[*sx * GRID + *sy] = make_node(VAL_START);
	g[*ex * GRID + *ey] = make_node(VAL_END);
}

static int load_maze(const char *path, uint32_t *g, int *sx, int *sy, int *ex, int *ey)
{
	FILE *f = fopen(path, "r");
	char line[512];
	int x, y, have_s = 0, have_e = 0;

	if (!f) { perror(path); return -1; }

	for (x = 0; x < GRID; x++) {
		if (!fgets(line, sizeof line, f)) {
			fprintf(stderr, "%s: ocekivano %d linija\n", path, GRID);
			fclose(f);
			return -1;
		}
		for (y = 0; y < GRID; y++) {
			char c = (y < (int)strlen(line)) ? line[y] : '.';
			uint32_t v = VAL_PATH;
			switch (c) {
			case '#': v = VAL_WALL;  break;
			case 'S': v = VAL_START; *sx = x; *sy = y; have_s = 1; break;
			case 'E': v = VAL_END;   *ex = x; *ey = y; have_e = 1; break;
			default:  v = VAL_PATH;  break;
			}
			g[x * GRID + y] = make_node(v);
		}
	}
	fclose(f);

	if (!have_s || !have_e) {
		fprintf(stderr, "%s: nedostaje S ili E\n", path);
		return -1;
	}
	return 0;
}

static void print_maze(const uint32_t *g)
{
	int x, y;

	for (x = 0; x < GRID; x++) {
		for (y = 0; y < GRID; y++) {
			char c;
			switch (node_dist(g[x * GRID + y])) {
			case VAL_WALL:  c = '#'; break;
			case VAL_START: c = 'S'; break;
			case VAL_END:   c = 'E'; break;
			case VAL_FINAL: c = '*'; break;
			default:        c = node_visited(g[x * GRID + y]) ? ',' : '.'; break;
			}
			putchar(c);
		}
		putchar('\n');
	}
}

/* ------------------------------------------------------------------------- */
/* Rekonstrukcija putanje (ono sto u SystemC modelu radi procesor)             */
/* ------------------------------------------------------------------------- */

static int reconstruct_path(uint32_t *g, int sx, int sy, int ex, int ey)
{
	int cx = ex, cy = ey;
	int steps = 0, len = 0;

	while (steps++ < N_NODES) {
		uint32_t nd = g[cx * GRID + cy];
		int px = node_px(nd), py = node_py(nd);

		/*
		 * IP dodeljuje roditelja samo susedu (8-okolina) trenutnog node-a.
		 * Ako roditelj nije sused, END nikada nije dostignut (parent bitovi su
		 * ostali 0) - lavirint je neresiv.
		 */
		if (abs(px - cx) > 1 || abs(py - cy) > 1)
			return -1;

		if (px == sx && py == sy)
			return len;                         /* stigli do START */

		g[px * GRID + py] = (g[px * GRID + py] & ~(0x1FFu << DIST_SHIFT))
				  | make_node(VAL_FINAL);
		len++;
		cx = px;
		cy = py;
	}
	return -1;
}

/* ------------------------------------------------------------------------- */
/* Softverski model IP FSM-a (pathfinder_ip.vhd) - za testiranje bez ploce     */
/* ------------------------------------------------------------------------- */

static uint32_t heuristic(int ix, int iy, int ex, int ey)
{
	int dx = abs(ex - ix), dy = abs(ey - iy);
	int diff = abs(dx - dy), minv = dx < dy ? dx : dy;
	return 2 * diff + 3 * minv;
}

static void sim_pathfinder(uint32_t *g, int sx, int sy, int ex, int ey)
{
	int cx = sx, cy = sy;
	int solved = 0;

	for (;;) {
		int i, j;

		/* EVAL: 8 suseda trenutnog node-a */
		for (i = cx - 1; i <= cx + 1 && !solved; i++)
			for (j = cy - 1; j <= cy + 1; j++) {
				uint32_t *nd;
				if (i < 0 || i >= GRID || j < 0 || j >= GRID || (i == cx && j == cy))
					continue;
				nd = &g[i * GRID + j];
				if (node_dist(*nd) == VAL_END) {
					*nd = make_node(VAL_END) | (cx << PX_SHIFT) | (cy << PY_SHIFT) | node_visited(*nd);
					solved = 1;
					break;
				} else if (node_dist(*nd) == 0) {
					*nd = make_node(heuristic(i, j, ex, ey)) | (cx << PX_SHIFT) | (cy << PY_SHIFT) | node_visited(*nd);
				}
			}
		if (solved)
			return;

		/* MOVE: globalni minimum neposecenog node-a sa 0 < dist < 298 */
		{
			uint32_t min_d = 511;
			int nx = -1, ny = -1, f;
			for (f = 0; f < N_NODES; f++) {
				uint32_t d = node_dist(g[f]);
				if (!node_visited(g[f]) && d > 0 && d < VAL_WALL && d < min_d) {
					min_d = d; nx = f / GRID; ny = f % GRID;
				}
			}
			if (nx < 0)
				return;                             /* neresivo */
			g[cx * GRID + cy] |= 1;                 /* visited */
			cx = nx; cy = ny;
		}
	}
}

/* ------------------------------------------------------------------------- */
/* Rad sa drajverom                                                            */
/* ------------------------------------------------------------------------- */

static int run_on_hw(uint32_t *g, int sx, int sy, int ex, int ey)
{
	int fb, fc, n;
	char cmd[64], resp[16];
	ssize_t r;

	fb = open(DEV_BRAM, O_RDWR);
	if (fb < 0) { perror("open " DEV_BRAM); return -1; }
	fc = open(DEV_CORE, O_RDWR);
	if (fc < 0) { perror("open " DEV_CORE); close(fb); return -1; }

	/* 1. ceo grid u BRAM jednim pozivom (40000 B) */
	if (pwrite(fb, g, N_NODES * 4, 0) != N_NODES * 4) {
		perror("pwrite grid");
		goto fail;
	}

	/* 2. koordinate + start */
	n = snprintf(cmd, sizeof cmd, "%d,%d,%d,%d", sx, sy, ex, ey);
	if (write(fc, cmd, n) != n) {
		perror("write " DEV_CORE);
		goto fail;
	}

	/* 3. cekaj prekid (blokirajuce citanje; timeout u drajveru je 10 s).
	 *    Drajver koristi endRead semantiku iz Vezbe 9: prvi read vraca "1\n",
	 *    a write() nove pretrage ponovo "naoruzava" read.                       */
	r = read(fc, resp, sizeof resp - 1);
	if (r < 0) {
		perror("read " DEV_CORE " (timeout - prekid nije stigao?)");
		goto fail;
	}
	resp[r] = '\0';
	printf("Drajver: done=%s", resp);

	/* 4. rezultat nazad iz BRAM-a */
	if (pread(fb, g, N_NODES * 4, 0) != N_NODES * 4) {
		perror("pread grid");
		goto fail;
	}

	close(fc);
	close(fb);
	return 0;
fail:
	close(fc);
	close(fb);
	return -1;
}

/* ------------------------------------------------------------------------- */

int main(int argc, char **argv)
{
	static uint32_t grid[N_NODES];
	int sx, sy, ex, ey, sim = 0, len;
	const char *maze = NULL;
	int a;

	for (a = 1; a < argc; a++) {
		if (!strcmp(argv[a], "--sim")) sim = 1;
		else maze = argv[a];
	}

	if (maze) {
		if (load_maze(maze, grid, &sx, &sy, &ex, &ey))
			return 1;
	} else {
		demo_maze(grid, &sx, &sy, &ex, &ey);
	}

	printf("START (%d,%d)  END (%d,%d)  [%s]\n", sx, sy, ex, ey, sim ? "SIM" : "HW");

	if (sim)
		sim_pathfinder(grid, sx, sy, ex, ey);
	else if (run_on_hw(grid, sx, sy, ex, ey))
		return 1;

	len = reconstruct_path(grid, sx, sy, ex, ey);
	print_maze(grid);

	if (len < 0)
		printf("\nNema putanje (END nije dostignut).\n");
	else
		printf("\nPutanja pronadjena, duzina %d koraka (* = putanja, ',' = posecen node).\n", len + 1);

	return 0;
}
