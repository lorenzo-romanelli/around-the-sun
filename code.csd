/******************************************************************/
/**************** PROGETTO PROGRAMMAZIONE TIMBRICA ****************/
/*********************** Lorenzo Romanelli ************************/
/***************************** 829694 *****************************/
/************************* A.A. 2015-2016 *************************/
/******************************************************************/

<CsoundSynthesizer>
<CsOptions>
</CsOptions>
<CsInstruments>

sr = 44100
kr = 4410
ksmps = 10
nchnls = 2
0dbfs = 1.0

/******************************************************************/
/************** Inizializzazione variabili globali ****************/
/******************************************************************/

garevL 		init		0	; riverbero (left channel)
garevR 		init 	0	; riverbero (right channel)
gadel		init		0	; delay


/***************************************************/
/************** User Defined Opcode ****************/
/******************* BITCRUSHER ********************/
/***************************************************/

; 	Simula la riduzione dei bit di quantizzazione e della frequenza di campionamento.
; 	Variabili in ingresso 
;		ain: segnale in ingresso,
;		kbitdpth: nuova profondità in bit, 
;		ksr: nuova freq. di campionamento.
;	Variabile restituita
;		aout: segnale ain riquantizzato e ricampionato

opcode	bitcrush, a, akk
	
			setksmps	1
	
	ain, \
	kbitdpth, \
	ksr 		xin
	
	kin		downsamp	ain			; converto il segnale da a-time a k-time 
	knlevels 	= 2^kbitdpth			; nuova quantità di livelli di quantizzazione 

	kin 	= kin + 32768				; aggiungo del DC offset per eliminare i valori negativi
	kin 	= kin * (knlevels / 32768*2)	; riquantizzazione del segnale
	kin	= int(kin)				; dei nuovi valori prendo solo la parte intera

	asig		upsamp	kin			; riconverto il nuovo segnale ad a-time
	asig		= asig * (32768*2 / knlevels) - 32768	; riamplifico il segnale e elimino il DC offset
	
	kcoeff 	= (sr/ksr)			; coefficiente di foldover
	aout		fold		asig, kcoeff	; ricampionamento (foldover artificiale)

			xout		aout

endop

/***************************************************/
/******************* Strumento 1 *******************/
/********************* ORGANO **********************/
/***************************************************/

;	Organo in sintesi additiva, con armoniche ottenute tramite filtraggio di rumore bianco.
;	Tecniche utilizzate:
;		Sintesi additiva
;		Sintesi sottrattiva

instr 1
	
	ibasefreq = cpspch(p4)	; armonica fondamentale
	istpos = p5			; posizione stereo
	ivol = p6				; volume post-fader
	irev = p7				; send riverbero
	
	; rumore modulante per la frequenza di centro banda dei filtri bandpass
	kfrqmod	rand		10, 2, 1, -5
	
	; LFO modulanti per l'ampiezza di banda dei filtri bandpass
	kh1fenv	oscili	1, .5, 1
	kh2fenv	oscili	2, 1.2, 1
	kh3fenv	oscili	1, 2.2, 1
	kh4fenv	oscili	2, .8, 1
	kh1fenv = kh1fenv + 5
	kh2fenv = kh2fenv + 4
	kh3fenv = kh3fenv + 3
	kh4fenv = kh4fenv + 2
	
	; rumore bianco da filtrare
	amod		rand		.1, 2, 1
	; banco di filtri bandpass a banda strettissima
	ah1		reson 	amod, ibasefreq + kfrqmod, kh1fenv, 0
	ah2		reson 	amod, ibasefreq*2 + kfrqmod, kh2fenv, 0
	ah3		reson	amod, ibasefreq*3 + kfrqmod, kh3fenv, 0
	ah4		reson	amod, ibasefreq*4 + kfrqmod, kh4fenv, 0
	
	; inviluppi di ampiezza per le singole armoniche 
	kh1venv	expseg 	0.00001, 0.010, .8, 0.022, .7, p3-0.532, .6, 0.5, 0.00001
	kh2venv	expseg	0.00001, 0.011, .5, 0.026, .4, p3-0.487, .2, 0.45, 0.00001
	kh3venv	expseg	0.00001, 0.028, .6, 0.016, .5, p3-0.454, .3, 0.41, 0.00001
	kh4venv	expseg	0.00001, 0.026, .4, 0.034, .3, p3-0.490, .2, 0.43, 0.00001
	; inviluppo di ampiezza globale
	kvenv	linseg	0, .01, 1, p3-0.02, 1, .01, 0

	; sommo le armoniche coi relativi inviluppi
	aharm = kvenv * ((ah1*kh1venv) + (ah2*kh2venv) + (ah3*kh3venv) + (ah4*kh4venv))

	; filtro il segnale con un passabasso per eliminare del rumore in eccesso
	afilt	tonex 	aharm, ibasefreq*10, 8
	
	; spazializzo
	aoutL = afilt * sqrt(1-istpos)
	aoutR = afilt * sqrt(istpos)
	
	; mando parte del segnale al riverberatore
	garevL = garevL + (aoutL*irev)
	garevR = garevR + (aoutR*irev)
	
			outs		aoutL*ivol, aoutR*ivol

endin

/***************************************************/
/******************* Strumento 2 *******************/
/******************** SYNTH FM *********************/
/***************************************************/

;	Sintetizzatore FM a tre voci dal carattere aggressivo.
;	Tecniche utilizzate:
;		Sintesi FM
;		Sintesi additiva
;		Sintesi sottrattiva

instr 2
	
	ipitch = cpspch(p4)			; pitch fondamentale
	idetune = cent(p5)			; parametro di detune rispetto al pitch fondamentale
	ipitch2 = ipitch * idetune	; pitch detunato (crescente) - seconda voce
	ipitch3 = ipitch / idetune	; pitch detunato (calante) - terza voce
	ispreadamt = p6			; quantità di spread
	ispread1 = sqrt(0.5)		; spread prima voce
	ispread2L = sqrt(1-ispreadamt)	; spread seconda voce (left channel)
	ispread2R = sqrt(ispreadamt)		; spread seconda voce (right channel)
	ispread3L = sqrt(1-ispreadamt*2)	; spread terza voce (left channel)
	ispread3R = sqrt(ispreadamt*2)	; spread terza voce (right channel)
	
	; inviluppo di ampiezza
	kvol		linseg	0, .05, .6, p3-3.05, .6, 3, 0, 1, 0
	; inviluppi di frequenza
	kpchenv	linseg	.5, 1, 1, 1, 1
	kpitch1 = ipitch * kpchenv
	kpitch2 = ipitch2 * kpchenv
	kpitch3 = ipitch3 * kpchenv
	
	; due oscillatori modulanti in cascata  
	kmod		oscili	10, 200				; prima modulante
	kmodamp	randi	50, 15, 2, 2, 500		; ampiezza seconda modulante controllata con valori randomici interpolati linearmente
	kmod1	oscili	kmodamp, kpitch1 + kmod	; seconda modulante (prima voce)
	kmod2	oscili	kmodamp, kpitch2 + kmod 	; seconda modulante (seconda voce)
	kmod3	oscili	kmodamp, kpitch3 + kmod	; seconda modulante (terza voce)
	
	; ogni voce è realizzata tramite due voltage controlled oscillators
	; a distanza di ottava modulati in frequenza dalla seconda modulante,
	; il primo ad onda triangolare, il secondo a dente di sega
	aoutB1 	vco2		.06, kmod1, 12
	aoutH1	vco2		.04, kmod1 * 2, 0
	aoutB2 	vco2		.06, kmod2, 12
	aoutH2	vco2		.04, kmod2 * 2, 0
	aoutB3 	vco2		.06, kmod3, 12
	aoutH3	vco2		.04, kmod3 * 2, 0
	
	; sommo i due oscillatori per voce
	aout1 = aoutB1 + aoutH1
	aout2 = aoutB2 + aoutH2
	aout3 = aoutB3 + aoutH3
	
	; spazializzo i due canali in base allo spread
	aL = (aout1*ispread1) + (aout2*ispread2L) + (aout3*ispread3L)
	aR = (aout1*ispread1) + (aout2*ispread2R) + (aout3*ispread3R)
	
	; LFO che controlla la frequenza di taglio del passabasso 
	klfo1freq	expseg	100, 5, 100, 5, 1, 1, 1	; frequenza dell'LFO
	klfo1	oscil	.495, klfo1freq, 3		; LFO che utilizza un'onda dente di sega discendente
	kcutfrq = klfo1 + .505 					; fattore che va da 0.01 a 1
	aL		tone		aL, 20000 * kcutfrq		; moltiplico la frequenza di taglio per il fattore calcolato
	aR		tone		aR, 20000 * kcutfrq

	; spazializzazione dinamica tramite LFO
	kpan		oscil	.35, .25
	kpan = kpan + .5
	
	; applico l'inviluppo di ampiezza e spazializzo 
	aoutL = aL * kvol * sqrt(1-kpan)
	aoutR = aR * kvol * sqrt(kpan)

	; mando parte del segnale al riverberatore
	garevR = garevR + aoutL * .3
	garevL = garevL + aoutR * .3

			outs		aoutL, aoutR

endin

/***************************************************/
/******************* Strumento 3 *******************/
/************** EFFETTI CON GRANULARE **************/
/***************************************************/

;	Strumento in grado di generare effetti tipo swoosh tramite sintesi granulare.
;	Tecniche utilizzate:
;		Sintesi granulare
;		Sintesi AM
;		Manipolazione suoni campionati

instr 3

	iatt = p4			; tempo di attacco
	irel = p5			; tempo di release
	ibasfreq = 1040	; frequenza fondamentale del suono campionato
	
	ipch1 = cpspch(p6) / ibasfreq		; fattore per ottenere il primo pitch
	ipch2 = cpspch(p7) / ibasfreq		; fattore per ottenere il secondo pitch
	ipch3 = cpspch(p8) / ibasfreq		; fattore per ottenere il terzo pitch
	ipch4 = cpspch(p9) / ibasfreq		; fattore per ottenere il quarto pitch
	inotes = p10					; numero di pitch effettivamente utilizzati
	
	istrtpan = p11		; posizione di pan iniziale
	ifinpan = p12		; posizione di pan finale
	ivol = p13		; volume post-fader
	irev = p14		; send riverbero
	
	; segnale modulante per AM con indice di modulazione variabile nel tempo
	kAMind	linseg	3, p3, 5
	kAMmod	oscili	kAMind, cpspch(p6) * 3
	; inviluppo di ampiezza
	kamp 	expseg	0.00001, iatt, 1, p3 - (iatt+irel), 1, irel, 0.00001
	; segnale modulante con inviluppo di ampiezza
	kAMmod = (kAMmod + kAMind) * kamp

	; sintesi granulare
	;																			skip		random	file
	;				ampiezza		voci		ratio	mode		thr		fn		npitches	time		skip		length		
	asig		granule	.1*kAMmod,	10,		1,		0,		0,		2,		inotes,	1.5,		.01,		.4,		\
			.001,	10,			.04,		2,		20,		20,		2,		ipch1,	ipch2,	ipch3,	ipch4
	;		gap		% gap	 	size		size		% att	% dec	seed		pitch1	pitch2	pitch3	pitch4
	;				offset				offset
				
	; spazializzazione variabile nel tempo
	kpan		linseg	istrtpan, p3 * .4, istrtpan, p3 * .2, ifinpan, p3 * .4, ifinpan
	aoutL = asig*sqrt(1-kpan)
	aoutR = asig*sqrt(kpan)

	; mando parte del segnale al riverberatore
	garevL = garevL + (aoutL*irev)
	garevR = garevR + (aoutR*irev)
	
			outs		aoutL*ivol, aoutR*ivol

endin

/***************************************************/
/******************* STRUMENTO 4 *******************/
/********************** SONAR **********************/
/***************************************************/

;	Simulazione del suono emesso dal sonar di un sottomarino.
;	Tecniche utilizzate:
;		Sintesi additiva
;		Sintesi RM
;		Sintesi sottrattiva

instr 4
	ipan = p4				; posizione stereo
	ipitch = cpspch(p5)		; pitch
	isweepf = ipitch/1000	; quantità di sweep sul pitch del suono
	iatt = 0.008			; tempo di attacco
	idec = 0.05			; tempo di decadimento
	irel = 2.8			; tempo di release
	ivol = p6				; volume post-fader
	irev = p7				; send riverbero
	
	; inviluppo di ampiezza del primo oscillatore (corpo del suono)
	kampenv	expseg	0.0001, iatt, 1, irel, 0.0001, 1, 0.0001
	; inviluppo di ampiezza del secondo oscillatore (attacco del suono)
	kattenv	linseg	0, iatt, .3, idec, 0, 1, 0
	; inviluppo di frequenza
	kfrqenv	linseg	ipitch, iatt, ipitch, irel, ipitch+isweepf, 1, ipitch+isweepf
	; inviluppo sulla frequenza di taglio del passabasso
	klpenv	linseg	20, iatt, 25, irel, 200
	
	; rumore bianco (filtrato) utilizzato per modulazione ad anello
	anoise	rand		1, 2
	ansmod	tonex	15 * anoise, klpenv, 4 

	asine	oscili	kampenv * ansmod, kfrqenv	; corpo del suono (con modulazione ad anello)
	aatt		oscili	kattenv, ipitch - 20		; attacco del suono
	
	; suono finale = corpo + attacco, il tutto filtrato con un passabasso
	ablip = asine + aatt
	ablip	tonex	ablip, 5000, 4
	
	; spazializzo
	aoutL = ablip * sqrt(1-p4)
	aoutR = ablip * sqrt(p4)
	
	; mando parte del segnale al riverberatore
	garevL = garevL + (aoutL*irev)
	garevR = garevR + (aoutR*irev)
	
			outs		aoutL*ivol, aoutR*ivol

endin

/***************************************************/
/******************* STRUMENTO 5 *******************/
/***************** CORDA PIZZICATA *****************/
/***************************************************/

;	Modello fisico di una corda pizzicata (utilizzata per generare suoni percussivi).
;	Tecniche utilizzate:
;		Sintesi per modelli fisici
;		Distorsione non lineare

instr 5
	
	ipitch = cpspch(p4)		; pitch
	imeth = p5			; metodo usato dall'opcode pluck
	iparm1 = p6			; parametro 1 eventualmente usato da pluck
	iparm2 = p7			; parametro 2 eventualmente usato da pluck
	idist = p8			; livello della distorsione
	idelay = p9			; send delay attivato / disattivato
	ivol = (imeth = 4 ? p10 * .6 : p10) ; volume post-fader
	
	; sintesi per modelli fisici
	apluck	pluck	.1, ipitch, ipitch, 0, imeth, iparm1, iparm2
	
	adist	tonex	apluck, 1000	; filtro il segnale con un passabasso
	adist = apluck * idist			; e lo amplifico in base a quanta distorsione voglio applicare 
	adist = adist / (1 + abs(adist))	; funzione distorcente (tipo soft-clipping), sempre limitata tra (-1 .. +1)
	asig		balance	adist, apluck	; bilancio l'RMS del segnale
	
	; inviluppo di ampiezza (per evitare suoni troncati allo spegnimento dello strumento)
	kenv		linseg	ivol, p3 * 0.9, ivol, p3 * 0.1, 0
	asig = asig * kenv
	
	; se il delay è attivo (idelay = 1) mando il segnale allo strumento delay
	gadel = gadel + asig * idelay 
	
	; mando parte del segnale al riverberatore
	garevL = garevL + asig * .7
	garevR = garevR + asig * .7	
			
			outs		asig, asig

endin

/***************************************************/
/******************* STRUMENTO 6 *******************/
/******************** "GATTACA" ********************/
/***************************************************/

;	Varie manipolazioni di un estratto audio dal film del 1997 Gattaca.
;	Tecniche utilizzate:
;		Manipolazione suoni campionati
;		Sintesi vettoriale
;		Distorsione tramite bitcrushing

instr 6

	ishft = p4		; rapporto tra pitch del segnale originale e pitch desiderato
	istvol = p5		; volume del segnale stereo originale iniziale
	iendvol = p6		; volume del segnale stereo originale finale
	imonoon = p7		; segnale mono attivato / disattivato
	ifadeio = p8		; tempo di fadein o fadeout (in base a p5 e p6)
	iskip = p9		; tempo saltato dall'inizio del file
	istpan = p10		; posizione stereo iniziale
	iendpan = p11		; posizione stereo finale
	
	; inviluppo di ampiezza per il segnale stereo originale
	kstervol	linseg	istvol, ifadeio, iendvol, 1, iendvol
	
	; inviluppo di ampiezza per il segnale mono
	kmonovol	linseg	0, 1, 0, p3-8, 2, 6, 0, 1, 0
	kmonovol = kmonovol * imonoon
	
	; carico il file stereo 
	aL, aR	diskin2	"gattaca.wav", ishft, iskip
	; e ne creo una copia mono
	amono = (aL+aR) * 0.5

	; simulazione di un altoparlante lo-fi
	icenter = (300 + 3000) * 0.5				; calcolo centro banda
	ibwd = (3000 - icenter) * 2				; e larghezza di banda
	aout		resonx	amono, icenter, ibwd	; filtro il segnale mono con un passabanda
	aout		bitcrush	aout, 8, 8000			; applico del bitcrushing (8-bit, frequenza di campionamento 8kHz)
	aout		butterbp	aout, icenter, ibwd		; filtro nuovamente il segnale con un altro passabanda
	aout		balance	aout, amono
	aout = aout * kmonovol
	; riverbero parte del segnale mono (stanza piccola)
	arvL,arvR	reverbsc	aout*.8, aout*.8, .2, 8000

	; posizione stereo variabile nel tempo
	kpan		expseg	istpan, p3/3, istpan, p3/6, iendpan, 1, iendpan

	; spazializzo segnali mono e stereo
	aoutL = (aout + aL * kstervol) * .4 * sqrt(1-kpan)
	aoutR = (aout + aR * kstervol) * .4 * sqrt(kpan)

			outs 	aoutL + arvL, aoutR + arvR

endin

/***************************************************/
/****************** STRUMENTO 98 *******************/
/***************** PING-PONG DELAY *****************/
/***************************************************/

;	Effetto di delay stereo ottenuto tramite due linee di ritardo + filtro passa alto.

instr 98
	
	ifeedback = p4		; percentuale di feedback del segnale
	ideltime = p5		; tempo di delay
	kpan = 1			; apertura dell'immagine stereo
	
	adel		init		0	; variabile contenente il feedback
	
	; prima linea di ritardo
	adelay1	delay	gadel + adel, ideltime
	adelay1	atone	adelay1, 500
	adelay1 = adelay1 * ifeedback
	
	; seconda linea di ritardo che opera sul primo delay
	adelay2	delay	adelay1, ideltime
	adel = adelay2 * ifeedback
	
	; spazializzo i due delay
	adelL = adelay1 * sqrt(1-kpan) + adelay2 * sqrt(kpan)
	adelR = adelay2 * sqrt(1-kpan) + adelay1 * sqrt(kpan)
	
	; mando il segnale al riverberatore 
	garevL = garevL + adelL
	garevR = garevR + adelR
	
			outs		adelL, adelR
	
	gadel = 0			; reset della variabile contenente il segnale da ritardare

endin

/***************************************************/
/****************** STRUMENTO 99 *******************/
/**************** RIVERBERO STEREO *****************/
/***************************************************/

;	Effetto di riverbero distribuito sui due canali.

instr 99

	a_revL, a_revR	reverbsc	garevL, garevR, .75, 12000
				outs		a_revL, a_revR
	
	garevL = 0	; reset delle due variabili contenenti il segnale da riverberare
	garevR = 0 

endin

</CsInstruments>
<CsScore>

; 	FUNZIONE 1: sine wave - GEN09
f1	0	4096	9	1 

; 	FUNZIONE 2: suono campionato di un bicchiere percosso con un coltello - GEN01
f2	0	0	1	"glass.wav"	0	0	0

;	FUNZIONE 3: periodo di dente di sega discendente - GEN07
f3	0	4096	7	0	2048	-1	0	1	2048	0

;------------------------------------------
; 	DELAY
;		p4 = percentuale di feedback
;		p5 = tempo di delay
;------------------------------------------
;	p2	p3	p4	p5
i98	30	30	.7	.125

;------------------------------------------
;	RIVERBERO
;------------------------------------------
;	p2	p3
i99 	0 	60

;------------------------------------------
; 	STRUMENTO 1: ORGANO
;		p4 = nota in OPPC
;		p5 = pan (da 0 a 1)
;		p6 = volume post-fader
;		p7 = send riverbero
;------------------------------------------
;	p2	p3	p4		p5	p6	p7
i1	42	5.5	9.00		.8	.004	.002
i1	.	.	9.04		.6	.	.
i1	.	.	8.00		.8	.003	.
i1	.	.	8.04		.6	.	.
i1	.	10.5	9.07		.4	.004	.
i1	.	.	9.09		.2	.	.
i1	.	.	8.07		.4	.003	.
i1	.	.	8.09		.2	.	.
i1	47	5.5	8.11		.8	.004	.
i1	.	.	9.02		.6	.	.
i1	.	.	7.11		.8	.003	.
i1	.	.	8.02		.6	.	.
i1	52	4	8.02		.5	.004	.004
i1	.	.	8.09		.	.	.
i1	.	.	7.02		.	.003	.003
i1	.	.	7.09		.	.	.

;------------------------------------------
;	STRUMENTO 2: SYNTH FM
;		p4 = nota in OPPC
;		p5 = detune delle voci in cent
;		p6 = spread stereo delle voci
;------------------------------------------
;	p2	p3	p4	p5	p6
i2	13	39 	4.02	12	.41
i2	.	.	5.02	.	.
i2	.	.	6.02	.	.
i2	.	.	6.09	.	.

;------------------------------------------
; 	STRUMENTO 3: EFFETTI CON SINTESI GRANULARE
;		p4 = tempo di attacco in secondi
;		p5 = tempo di release in secondi
;		p6 = pitch 1 utilizzato dall'opcode granule (OPPC)
;		p7 = pitch 2
;		p8 = pitch 3
;		p9 = pitch 4
;		p10 = note effettivamente usate
;		p11 = pan iniziale
;		p12 = pan finale
;		p13 = volume post-fader
;		p14 = send riverbero
;------------------------------------------
;	p2	p3	p4	p5	p6		p7		p8		p9		p10	p11	p12	p13	p14
i3	3	27	9	18	6.00		4.09		5.10		8.03		4	.3	.5	.08	.5
i3	9	9	4	5	12.08	13.04	11.01	13.00	4	.81	.22	.2	.6
i3	22	34	18	9.5	11.09	12.09	0		0		2	.75	.75	.001	.3
i3	27	8	2.8	4.8	8.02		9.02		7.02		7.09		4	.98	.02	.01	.7
i3	35	.	.	.	8.00		9.00		7.00		7.07		4	.98	.02	.1	.9
i3	48	9	5	4	8.02		9.02		7.02		6.10		4	.22	.88	.05	.8

;------------------------------------------
;	STRUMENTO 4: SONAR
;		p4 = pan
;		p5 = nota in OPPC
;		p6 = volume post-fader
;		p7 = send riverbero
;------------------------------------------
;	p2	p3	p4	p5	p6	p7
i4 	31	4	.01	9.02	.4	.6
i4 	+ 	.	.1	.	.6	.
i4	+	.	.1	9.00	.8	.
i4	55	2	.1	9.02	1	.

;------------------------------------------
;	STRUMENTO 5: CORDA PIZZICATA
;		p4 = nota in OPPC
;		p5 = metodo usato dall'opcode pluck
;		p6 = parametro 1 utilizzabile da pluck
;		p7 = parametro 2
;		p8 = quantità di distorsione da applicare (qualsiasi valore è accettato)
;		p9 = delay off/on (0/1)
;		p10 = volume post-fader
;------------------------------------------
;	p2		p3	p4	p5	p6	p7	p8	p9	p10
i5	25		.5	7.02	4	.2	10	1	0	.05
i5	.		.	7.07	5	.5	.3	100	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	25.25	.	7.06	.	.	.	.	. 	.
i5	.		.	8.06	.	.	.	.	. 	.

i5	^+.25	.	7.02	4	.2	10	1	.	<
i5	^+0		.	7.07	5	.5	.3	100	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	<
i5	^+0		.	7.07	5	.5	.3	100	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	<
i5	^+0		.	7.07	5	.5	.3	100	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	<
i5	^+0		.	7.07	5	.5	.3	100	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	<
i5	^+0		.	7.07	5	.5	.3	100	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	<
i5	^+0		.	7.07	5	.5	.3	100	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	<
i5	^+0		.	7.07	5	.5	.3	100	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	<
i5	^+0		.	7.07	5	.5	.3	100	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	<
i5	^+0		.	7.07	5	.5	.3	100	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	<
i5	^+0		.	7.07	5	.5	.3	100	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	<
i5	^+0		.	7.07	5	.5	.3	100	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	<
i5	^+0		.	7.07	5	.5	.3	100	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	<
i5	^+0		.	7.07	5	.5	.3	100	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	<
i5	^+0		.	7.07	5	.5	.3	100	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	<
i5	^+0		.	7.07	5	.5	.3	100	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	<
i5	^+0		.	7.07	5	.5	.3	100	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	<
i5	^+0		.	7.07	5	.5	.3	100	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	1	.8
i5	^+0		.	7.07	5	.5	.3	100	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	.
i5	^+0		.	7.07	5	.5	.4	200	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	.
i5	^+0		.	7.07	5	.5	.4	300	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	.
i5	^+0		.	7.07	5	.5	.4	400	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	.
i5	^+0		.	7.07	5	.5	.4	500	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	.
i5	^+0		.	7.07	5	.5	.4	600	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	.
i5	^+0		.	7.07	5	.5	.4	700	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	.
i5	^+0		.	7.07	5	.5	.4	800	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	.
i5	^+0		.	7.07	5	.5	.4	900	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	.
i5	^+0		.	7.07	5	.5	.4	1000	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	.
i5	^+0		.	7.07	5	.5	.4	1100	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	.
i5	^+0		.	7.07	5	.5	.4	1200	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	.
i5	^+0		.	7.07	5	.5	.4	1300	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	.
i5	^+0		.	7.07	5	.5	.4	1400	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	.
i5	^+0		.	7.07	5	.5	.4	1500	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	.
i5	^+0		.	7.07	5	.5	.4	1600	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	.
i5	^+0		.	7.07	5	.5	.4	1700	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	.
i5	^+0		.	7.07	5	.5	.4	1800	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	<
i5	^+0		.	7.07	5	.5	.4	1900	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	<
i5	^+0		.	7.07	5	.5	.4	1600	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	<
i5	^+0		.	7.07	5	.5	.4	1700	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	<
i5	^+0		.	7.07	5	.5	.4	1800	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	<
i5	^+0		.	7.07	5	.5	.4	1900	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	<
i5	^+0		.	7.07	5	.5	.4	2000	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	<
i5	^+0		.	7.07	5	.5	.4	2100	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	<
i5	^+0		.	7.07	5	.5	.4	2200	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

i5	^+.25	.	7.02	4	.2	10	1	.	.1
i5	^+0		.	7.07	5	.5	.4	2300	.	.
i5	.		.	8.07	.	.	.	.	. 	.
i5	^+.25	.	7.06	.	.	.	.	. 	.
i5	^+0		.	8.06	.	.	.	.	.	.

;------------------------------------------
;	STRUMENTO 6: "GATTACA"
;		p4 = rapporto tra pitch originale e pitch desiderato
;			(valori negativi = lettura in reverse)
;		p5 = volume iniziale
;		p6 = volume finale
;		p7 = mono off/on (0/1)
;		p8 = tempo di fadein o fadeout
;		p9 = secondi saltati dall'inizio del file
;		p10 = pan iniziale
;		p11 = pan finale
;------------------------------------------
;	p2	p3	p4	p5	p6	p7	p8	p9	p10	p11
i6	0	4	-2	0	3	0	1	12	.1	.9
i6	.5	3.5	-2.1	.	4	.	.	<	<	<
i6	1	3	-2.5	.	2.6	.	.	<	<	<
i6	1.4	2.5	-2.8	.	1.8	.	.	<	<	<
i6	1.7	2.2	-3	.	1.5	.	.	<	<	<
i6	1.9	1	-3.2	.	2	.	.	5	.9	.1
i6	3	12.5	1	3	0	1	4.5	.5	.5	.9


</CsScore>
</CsoundSynthesizer>
<bsbPanel>
 <label>Widgets</label>
 <objectName/>
 <x>100</x>
 <y>100</y>
 <width>320</width>
 <height>240</height>
 <visible>true</visible>
 <uuid/>
 <bgcolor mode="nobackground">
  <r>255</r>
  <g>255</g>
  <b>255</b>
 </bgcolor>
</bsbPanel>
<bsbPresets>
</bsbPresets>
