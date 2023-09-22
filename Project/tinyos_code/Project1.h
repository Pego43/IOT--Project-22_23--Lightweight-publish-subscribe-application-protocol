/*
	Project1.h
	Authors: Gabriele Perego 10488414, Claudio Eutizi 10812073
*/


#ifndef PROJECT1_H
#define PROJECT1_H

#define MESSAGE_BUFFER_DIMENSION 10  

typedef nx_struct Msg
{

  	// MESSAGE TYPE: type = 0: CONN, type = 1: CONNACK, type = 2: SUB, type = 3: SUBACK, type = 4: PUB
  	nx_uint8_t type;
  	
  	// MESSAGE TOPIC: topic = 0: TEMPERATURE, topic = 1: HUMIDITY, topic = 2: LUMINOSITY
	nx_uint8_t topic;
  	
  	//information about message sender and destination
	nx_uint8_t sender;
	nx_uint8_t destination;
	
	// data to be sent to NODE-RED
	nx_uint8_t data; 
	
	
}msg_t;

//defining a msg queue with its operations

typedef nx_struct MsgQueue 
{
	msg_t buffer[MESSAGE_BUFFER_DIMENSION];
	nx_int16_t front;
	nx_int16_t rear;
	nx_int16_t count;
	
} queue_t;

void queueInit(queue_t* queue);
bool enqueue(queue_t* queue, msg_t* msg);
bool dequeue(queue_t* queue, msg_t* msg);
bool peek(queue_t* q, msg_t* msg);
void printQueue(queue_t q);


bool connReceived[8] 				= {FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE};		// Contains booleans that store whether the PAN received the CONN message from the node
bool connAckReceived[8] 			= {FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE}; 	// Contains booleans that store whether the node received the CONNACK from the PAN
int8_t topicSubscriptions[8] 		= {0, 1, 1, 0, 2, 1, 2, 0};										// Contains each node's subscription.
bool subReceived[8] 				= {FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE}; 	// Contains booleans that store whether the PAN received the SUB message from the node
bool subAckReceived[8] 				= {FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE}; 	// Contains booleans that store whether the node received the SUBACK from the PAN

enum
{
	AM_RADIO_COUNT_MSG = 10,
};

#endif
