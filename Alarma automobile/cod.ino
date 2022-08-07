#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>
#include <Wire.h>
#include <SoftwareSerial.h>

SoftwareSerial mySerial(3, 2);

//ULTRASONIC
unsigned int HighByte = 0;
unsigned int LowByte  = 0;
unsigned int Len  = 0;


//SUNET
const int mic =  4;
int state=0;



//ACCELEROMETRU
Adafruit_MPU6050 mpu;


//BUZZER
int buzzPin=8;



void setup() {
  Serial.begin(9600);
  mySerial.begin(9600);
  
  //BUZZER
  pinMode(buzzPin,OUTPUT);

  
  // MICROFON
  pinMode(mic, INPUT);

  
   // ACCELEROMETRU
  if (!mpu.begin()) {
    Serial.println("Failed to find MPU6050 chip");
    while (1) {
      delay(10);
    }
  }
  mpu.setHighPassFilter(MPU6050_HIGHPASS_0_63_HZ);
  mpu.setMotionDetectionThreshold(10);
  mpu.setMotionDetectionDuration(20);
  mpu.setInterruptPinLatch(true);
  mpu.setInterruptPinPolarity(true);
  mpu.setMotionInterrupt(true);
  delay(100);
}

void loop() {

/////////////////////ACCELEROMETRU
  if(mpu.getMotionInterruptStatus())
  {
    sensors_event_t a, g, temp;
    mpu.getEvent(&a, &g, &temp);
    Serial.print("Alarma a fost activata datorita sistemului de detectie a socurilor! \n ");
      for (int i = 0; i < 250; i++) 
      { 
      tone(8, 4000, 2000);
    }
  }
  delay(10);

  
/////////////////////ULTRASONIC

   mySerial.flush();
   mySerial.write(0X55);                           
   delay(500);        
   HighByte = mySerial.read();
   LowByte  = mySerial.read();
   Len  = HighByte * 256 + LowByte;
   if ((Len > 100) && (Len < 200))
   {
    Serial.print("Alarma a fost activata datorita sistemului de detectie a miscarii!\n");
    tone(8, 4000, 2000);
   }

   
/////////////////////////////MICROFON
  if(state==0 && digitalRead(mic) == 1){
    Serial.print("Alarma a fost activata datorita sistemului de detectie a sunetului!\n ");
    state=1;
    for (int i = 0; i < 280; i++)
    tone(8, 4000, 2000);
    delay(50);
  }
  if(state==1&&digitalRead(mic)==1)
  {
    state=0;
    delay(50);
  }

  
}
