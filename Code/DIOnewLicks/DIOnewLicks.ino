/*
  ----------------------------------------------------------------------------

  This file is part of the Sanworks Bpod_Gen2 repository
  Copyright (C) 2017 Sanworks LLC, Stony Brook, New York, USA

  ----------------------------------------------------------------------------

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, version 3.

  This program is distributed  WITHOUT ANY WARRANTY and without even the
  implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.

*/
// DIO Module interfaces the Bpod state machine with TTL signals on Arduino digital pins.
// Pins 2-7 are configured as input channels, pins 19-23 are configured as output channels.
// A 2-byte serial message from the state machine sets the state of the output lines: [Channel (19-23), State(0 or 1)].
// A 3-byte serial message from the state machine enables or disables input lines: ['E' Channel (2-7), State (0 = disabled, 1 = enabled)]

#include "ArCOM.h" // Import serial communication wrapper
#include <Wire.h>
#include "MPR121.h"

// Module setup
char moduleName[] = "DIOnewLicks"; // Name of module for manual override UI and state machine assembler
char* eventNames[] = {"2_Hi", "2_Lo", "3_Hi", "3_Lo", "4_Hi", "4_Lo", "5_Hi", "5_Lo", "6_Hi", "6_Lo"};
#define FirmwareVersion 1
#define InputOffset 2
#define OutputOffset 3
#define nInputChannels 1
#define nOutputChannels 15
uint32_t refractoryPeriod = 300; // Minimum amount of time (in microseconds) after a logic transition on a line, before its level is checked again.
                                  // This puts a hard limit on how fast each channel on the board can spam the state machine with events.

// Constants
#define InputChRangeHigh InputOffset+nInputChannels
#define OutputChRangeHigh OutputOffset+nOutputChannels

byte nEventNames = (sizeof(eventNames)/sizeof(char *));


// Variables
byte opCode = 0;
byte channel = 0;
byte state = 0;
byte thisEvent = 0;
boolean readThisChannel = false; // For implementing refractory period (see variable above)
byte inputChState[nInputChannels] = {0}; // Current state of each input channel
byte lastInputChState[nInputChannels] = {0}; // Last known state of each input channel
byte inputsEnabled[nInputChannels] = {0}; // For each input channel, enabled or disabled
uint32_t inputChSwitchTime[nInputChannels] = {0}; // Time of last detected logic transition
byte events[nInputChannels*2] = {0}; // List of high or low events captured this cycle
byte nEvents = 0; // Number of events captured in the current cycle
uint32_t currentTime = 0; // Current time in microseconds

int buzzer = 20;
int houseLight = 21;
int irqpin = 2;

boolean touchStates[12]; 


void setup()
{
  Serial1.begin(1312500);
  currentTime = micros();
  for (int i = 0; i < nInputChannels; i++) {
    pinMode(i+InputOffset, INPUT_PULLUP);
    inputsEnabled[i] = 1;
    inputChState[i] = 1;
    lastInputChState[i] = 1;
  }
  for (int i = OutputOffset; i < OutputChRangeHigh; i++) {
    pinMode(i, OUTPUT);
  }

  pinMode(buzzer, OUTPUT);
  pinMode(houseLight, OUTPUT);

  pinMode(irqpin,INPUT);
  digitalWrite(irqpin, HIGH); //enable pullup resistor

  Wire.begin();

  mpr121_setup();
  
}

void loop()
{
  currentTime = micros();
  if (Serial1COM.available()) {
    opCode = Serial1COM.readByte();
    if (opCode == 255) {
      returnModuleInfo();
    }else if (opCode == 254){
      tone(buzzer,4000,200);
      state = Serial1COM.readByte();
    }else if (opCode == 253){
      tone(buzzer,4500,50);
      state = Serial1COM.readByte();
    }else if (opCode == houseLight){
      state = Serial1COM.readByte(); 
      digitalWrite(opCode,state); 
    }else if ((opCode >= OutputOffset) && (opCode < OutputChRangeHigh)) {
        state = Serial1COM.readByte(); 
        digitalWrite(opCode,state); 
    }
  }
  thisEvent = 1;
  for (int i = 0; i < nInputChannels; i++) {
    if (inputsEnabled[i] == 1) {
      inputChState[i] = digitalRead(i+InputOffset);
      readThisChannel = false;
      if (currentTime > inputChSwitchTime[i]) {
        if ((currentTime - inputChSwitchTime[i]) > refractoryPeriod) {
          readThisChannel = true;
        }
      } else if ((currentTime + 4294967296-inputChSwitchTime[i]) > refractoryPeriod) {
        readThisChannel = true;
      }
      if (readThisChannel) {
        if ((inputChState[i] == 1) && (lastInputChState[i] == 0)) {
          events[nEvents] = thisEvent; nEvents++;
          inputChSwitchTime[i] = currentTime;
          lastInputChState[i] = inputChState[i];
        }
        if ((inputChState[i] == 0) && (lastInputChState[i] == 1)) {
          events[nEvents] = thisEvent+1; nEvents++;
          inputChSwitchTime[i] = currentTime;
          lastInputChState[i] = inputChState[i];
        }
      }
    }
    thisEvent += 2;
  }
  if (nEvents > 0) {
    Serial1COM.writeByteArray(events, nEvents);
    nEvents = 0;
  }
}

void returnModuleInfo() {
  Serial1COM.writeByte(65); // Acknowledge
  Serial1COM.writeUint32(FirmwareVersion); // 4-byte firmware version
  Serial1COM.writeByte(sizeof(moduleName)-1);
  Serial1COM.writeCharArray(moduleName, sizeof(moduleName)-1); // Module name
  Serial1COM.writeByte(1); // 1 if more info follows, 0 if not
  Serial1COM.writeByte('#'); // Op code for: Number of behavior events this module can generate
  Serial1COM.writeByte(nInputChannels*2); // 2 states for each input channel
  Serial1COM.writeByte(1); // 1 if more info follows, 0 if not
  Serial1COM.writeByte('E'); // Op code for: Behavior event names
  Serial1COM.writeByte(nEventNames);
  for (int i = 0; i < nEventNames; i++) { // Once for each event name
    Serial1COM.writeByte(strlen(eventNames[i])); // Send event name length
    for (int j = 0; j < strlen(eventNames[i]); j++) { // Once for each character in this event name
      Serial1COM.writeByte(*(eventNames[i]+j)); // Send the character
    }
  }
  Serial1COM.writeByte(0); // 1 if more info follows, 0 if not
}

void mpr121_setup(void){

  set_register(0x5A, ELE_CFG, 0x00); 
  
  // Section A - Controls filtering when data is > baseline.
  set_register(0x5A, MHD_R, 0x01);
  set_register(0x5A, NHD_R, 0x01);
  set_register(0x5A, NCL_R, 0x00);
  set_register(0x5A, FDL_R, 0x00);

  // Section B - Controls filtering when data is < baseline.
  set_register(0x5A, MHD_F, 0x01);
  set_register(0x5A, NHD_F, 0x01);
  set_register(0x5A, NCL_F, 0xFF);
  set_register(0x5A, FDL_F, 0x02);
  
  // Section C - Sets touch and release thresholds for each electrode
  set_register(0x5A, ELE0_T, TOU_THRESH);
  set_register(0x5A, ELE0_R, REL_THRESH);
 
  set_register(0x5A, ELE1_T, TOU_THRESH);
  set_register(0x5A, ELE1_R, REL_THRESH);
  
  set_register(0x5A, ELE2_T, TOU_THRESH);
  set_register(0x5A, ELE2_R, REL_THRESH);
  
  set_register(0x5A, ELE3_T, TOU_THRESH);
  set_register(0x5A, ELE3_R, REL_THRESH);
  
  set_register(0x5A, ELE4_T, TOU_THRESH);
  set_register(0x5A, ELE4_R, REL_THRESH);
  
  set_register(0x5A, ELE5_T, TOU_THRESH);
  set_register(0x5A, ELE5_R, REL_THRESH);
  
  set_register(0x5A, ELE6_T, TOU_THRESH);
  set_register(0x5A, ELE6_R, REL_THRESH);
  
  set_register(0x5A, ELE7_T, TOU_THRESH);
  set_register(0x5A, ELE7_R, REL_THRESH);
  
  set_register(0x5A, ELE8_T, TOU_THRESH);
  set_register(0x5A, ELE8_R, REL_THRESH);
  
  set_register(0x5A, ELE9_T, TOU_THRESH);
  set_register(0x5A, ELE9_R, REL_THRESH);
  
  set_register(0x5A, ELE10_T, TOU_THRESH);
  set_register(0x5A, ELE10_R, REL_THRESH);
  
  set_register(0x5A, ELE11_T, TOU_THRESH);
  set_register(0x5A, ELE11_R, REL_THRESH);
  
  // Section D
  // Set the Filter Configuration
  // Set ESI2
  set_register(0x5A, FIL_CFG, 0x04);
  
  // Section E
  // Electrode Configuration
  // Set ELE_CFG to 0x00 to return to standby mode
  set_register(0x5A, ELE_CFG, 0x0C);  // Enables all 12 Electrodes
  
  
  // Section F
  // Enable Auto Config and auto Reconfig
  /*set_register(0x5A, ATO_CFG0, 0x0B);
  set_register(0x5A, ATO_CFGU, 0xC9);  // USL = (Vdd-0.7)/vdd*256 = 0xC9 @3.3V   set_register(0x5A, ATO_CFGL, 0x82);  // LSL = 0.65*USL = 0x82 @3.3V
  set_register(0x5A, ATO_CFGT, 0xB5);*/  // Target = 0.9*USL = 0xB5 @3.3V
  
  set_register(0x5A, ELE_CFG, 0x0C);
  
}


boolean checkInterrupt(void){
  return digitalRead(irqpin);
}


void set_register(int address, unsigned char r, unsigned char v){
    Wire.beginTransmission(address);
    Wire.write(r);
    Wire.write(v);
    Wire.endTransmission();
}
