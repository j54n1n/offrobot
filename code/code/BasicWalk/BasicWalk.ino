#include <ArduinoRobotMotorBoard.h>

void setup(){
  RobotMotor.begin();
  RobotMotor.motorsWrite(250,250);
}

void loop(){
}
