module music2
(
    // Z80 
    output  SRDB,
    output  SWRB, 

    //PLD23 
    output  SEL6295, 

    // SEI80BU 
    // input 14.13Mhz
    input   N1H,
    input   N6M, 

    // CONTROLLER SEI??
    input   MUSIC, 
    input   MWRLB,
    input   MRDLB,
    input   [3:1]   MAB,
    input   [7:0]   MDB,
    input   IRQ3812,
    input   COIN1,
    input   COIN2, 
    output  COUNTER1, //output ? ? 
    output  COUNTER2, //? 
    output  CS3812    //output 

    //74HC74
    //output CLK3_6, 
    //output PRCLK1
);

//Z80

//PLD 23

// 2kx8 slim package
// Z80 RAM

// 64kx8 rom

// SEI 01 ?? 
// 2151/5205 controller 

// SEI0080 SCRAMBLER 

// 74HC74
// -> clk 3.6M
//

// 74HC74 
// PRCLK1 -> clk1 mhz ?

endmodule 
