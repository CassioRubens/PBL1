@-----------------@
// Cássio Rubens Aragão Costa
// Raul do Carmo Peixoto
@-----------------@

@ declaração de constantes
.equ s_open, 5 // SYSCALL abertura/criar arquivo
.equ s_mmap2, 192 // Gera o endreço virtual

.equ S_RDWR, 0666 // Habilitar modo de escrita e leirua
.equ PROT_WRITE, 2 
.equ PROT_READ, 1 
.equ O_RDWR,	00000002 // Leitura e escrita
.equ O_SYNC,	00010000 // Sincronização
.equ pagelen, 4096	// Paginação de memorória 
.equ MAP_SHARED, 1 // Ativar o compartilhamento de memorória

@-------REGISTRADORES---------@
.equ UART_CR, 0x30 // Controle
.equ UART_FR, 0X18 // Flags 
.equ UART_DR, 0x0  // Dados
.equ UART_LCRH, 0x2c // Linha de controle

@-------BAUDRATE--------@
.equ UART_IBRD, 0x24 // Divisor inteiro
.equ UART_FBRD, 0x28 // Divisor fracionário

@-----------------------@
.equ UART_UARTEN, (1<<0) // UART
.equ UART_PEN, (1<<1) // Paridade
.equ UART_PT, (0<<2) //  Paridade 0 = ÍMPAR
.equ UART_STP2, (1<<3) // 2 bits de STOP BITS
.equ UART_FEN, (1<<4) // Habilitar FIFO
.equ UART_TXFF, (1<<5) // Verifica se a FIFO está cheia
.equ UART_WLEN1, (1<<6) // Bit mais significativo
.equ UART_LPE, (1<<7) // Loopback
.equ UART_TXE, (1<<8) // Transmissão
.equ UART_RXE, (1<<9) // Recepção
.equ FINALBITS, (UART_RXE|UART_TXE|UART_UARTEN|UART_LPE) // UART, TRANSMISSÃO/RECEPÇÃO, LOOPBACK
.equ UART_FIFOEN, (1<<4) // Habilitar A FIFO
.equ UART_FIFOCLR, (0<<4) // Desabilitar A FIFO
.equ BITS, (UART_WLEN1|UART_WLEN0|UART_FEN|UART_STP2|UART_PEN|UART_PT) // (Tamanho do dado, Paridade, STOP BITS, HABILITAR FIFO) 
.equ UART_WLEN0, (1<<5) // Bit menos significativo
.align 2

.data
mem: .asciz "/dev/mem" // diretório 
endereco: .word 0x20201 // endereço base da UART PL011
.align 2 

.section .text
.global _start
_start: 
	ldr r0, =mem // dev/mem abrindo diretório
        ldr r1, =(O_RDWR + O_SYNC) // permissão de leitura e escrita
        mov r7, #s_open // chamada de sistema para abertura do arquivo        
        svc 0	
 	movs r4, r0 // fd for memmap 

@ Mapeamento
    ldr r5, =endereco // endereço da uart / 4096
 	ldr r5, [r5] 
 	mov r1, #pagelen // paginação de memória
 	mov r2, #(PROT_READ + PROT_WRITE)
 	mov r3, #MAP_SHARED // compartilhar memorória com outros processos
 	mov r0, #0 // Clear
 	mov r7, #s_mmap2 // Chamada de sistema
 	svc 0
 	movs r5, r0 

    @ Reset Uart
    mov r0, #0
    str r0, [r5, #UART_CR]  // Zera o resgistrador de controle
								   

@ TRANSMIÇÃO/RECEPÇÃO
// Verificando o armazenamento da FIFO
l_fifo: ldr r2, [r5, #UART_FR]
tst r2, #UART_TXFF @ ESPERANDO 0 
    bne l_fifo
        
@ Desabilitando fifo
	ldr r1, [r5, #UART_LCRH] // carreganddo o endereço do resgistrador LCRH 
	mov r0, #1 				
	lsl r0, #4				
	bic r1, r0				
	str r1, [r5, #UART_LCRH]

@ Setando baudrate
	@Clock=3000000MHZ // para os calculos baterem com o osciloscópio
	@Bauddiv =  ClockUart/16*Baudrate
	@Calculo fracionário - Parte inteira[(BRFx64) + 0.5] 	
	mov r0, #0x13 // parte inteira da bauddiv
	str r0, [r5, #UART_IBRD]
	mov r0, #0x22 // parte fracionária da bauddiv
	str r0, [r5, #UART_FBRD]


@ habilitando transmissão e recepção
	ldr r0, = FINALBITS 
    str r0, [r5, #UART_CR]

@ Ativando a FIFO
	mov r0, #BITS
	str r0, [r5, #UART_LCRH]

@ Enviando dados
    mov r0, #0b00110000 //48
	str r0, [r5, #UART_DR]
	
_end:   mov r0, #0 
        mov r7, #1 
        svc 0 
