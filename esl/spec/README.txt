Projekat: Pronalaženje optimalne putanje na 2D grid mapi zasnovane na GBFS algoritmu

---Opis:
	Ovaj projekat koristi biblioteku raylib.h

---Instalacija
	Pratite sledeće korake kako biste instalirali potrebne zavisnosti i biblioteku raylib na vašem računaru:

	1. Dodajte PPA za raylib.h:

	sudo add-apt-repository ppa:texus/raylib

	2. Ažurirajte listu paketa:
	
	sudo apt update

	3. Instalirajte biblioteku:

	sudo apt install libraylib5-dev


---Uputstvo za korišćenje Makefile-a:

	make all - kompajlira GUI i terminal verziju
	make gui - kompajlira samo GUI verziju (specGUI/gui)
	make terminal - kompajlira samo terminal verziju (specTerminal/terminal)
	make clean - briše izvršne fajlove
