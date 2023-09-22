/*
	Project1AppC.nc
	Authors: Gabriele Perego 10488414, Claudio Eutizi 10812073
*/

#include "Project1.h"

configuration Project1AppC {}

implementation
{
	components MainC, Project1C as App;
	components new AMSenderC(AM_RADIO_COUNT_MSG);
	components new AMReceiverC(AM_RADIO_COUNT_MSG);
	components new TimerMilliC() as MilliTimer;
	components ActiveMessageC;
	components RandomC;
	  
	App.Boot -> MainC.Boot;
	App.Receive -> AMReceiverC;
	App.AMSend -> AMSenderC;
	App.AMControl -> ActiveMessageC;
	App.MilliTimer -> MilliTimer;
	App.Packet -> AMSenderC;
	App.Random -> RandomC;
}

