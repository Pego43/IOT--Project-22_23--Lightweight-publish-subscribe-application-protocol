/*
	Project1C.nc
	Authors: Gabriele Perego 10488414, Claudio Eutizi 10812073
*/

#include "Timer.h"
#include "Project1.h"
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/socket.h>

#define SERVER_IP "127.0.0.1"  // Localhost IP address
#define SERVER_PORT 1048      // server port

// topics
#define TEMPERATURE 0
#define HUMIDITY 1
#define LUMINOSITY 2

module Project1C @safe()
{
	uses 
	{
		interface Boot;
		interface Receive;
		interface AMSend;
		interface Timer<TMilli> as MilliTimer;
		interface SplitControl as AMControl;
		interface Packet;
		interface Random;
	}	
}

implementation
{
	message_t packet;
	
	// Socket for tcp connection to Node-red
	int sockfd;
    struct sockaddr_in servaddr;

	bool locked;
	
	uint8_t i;
  	uint8_t j;
  	uint8_t idx;
  	
  	queue_t* queue;
  	
  	
  	//implementation of the queue functions
  	
	void queueInit(queue_t* q)
	{	
		q->front = 0;
		q->rear = -1;
		q->count = 0;
	}
  	
  	
	bool enqueue(queue_t* q, msg_t* msg)
	{
		if (q -> count >= MESSAGE_BUFFER_DIMENSION) {
        	return FALSE; // Queue is full
    	} else {
			q -> rear = (q -> rear + 1) % MESSAGE_BUFFER_DIMENSION;
			memcpy(&(q -> buffer[q -> rear]), msg, sizeof(msg_t));
			q -> count++;
			return TRUE;
		}
	}
	
	//dequeueing the first element of the queue
	bool dequeue(queue_t* q) {
		if (q -> count <= 0) {
		    return FALSE; // Queue is empty
		}
		q -> front = (q -> front + 1) % MESSAGE_BUFFER_DIMENSION;
		q -> count--;
		return TRUE;
	}
	
	//taking the first element of the queue without dequeueing it
	bool peek(queue_t* q, msg_t* msg) {
		if (q->count <= 0) {
		    // Queue is empty
		    return FALSE;
		}

		// Copy the first element to the provided msg pointer
		memcpy(msg, &(q -> buffer[q -> front]), sizeof(msg_t));

		return TRUE;
    
	}
	
	void printQueue(queue_t* q){
		msg_t* msg;
		if(q->count == 0) 
		{
			dbg("queue", "Empty queue\n");
			return;
		}
		
		dbg("queue","Printing messages in the queue.\n");
		for(j = 0; j < q->count; j++)
		{
			idx = (q->front + j) % MESSAGE_BUFFER_DIMENSION;
			msg = &(q->buffer[idx]);
			dbg("queue", "position: %d. Message Topic: %d, Sender: %d, Data: %d\n", idx, msg -> topic, msg -> sender, msg -> data);
		}
	}
	
	
	
	
	// random values generation functions
	
	// Generate a random temperature within the specified range
	uint8_t generateRandomValue(uint8_t topic) {
	
		uint8_t value;
		uint16_t rand;
		//dbg("radio", "random value: %d\n", rand);
		switch(topic) {
		
			case TEMPERATURE:
				// Map the random number to the temperature range [0, 40]°C
				rand = call Random.rand16();
				value = (uint8_t)(rand % 41);
				//dbg("radio", "computed temperature value: %d\n", value);
				break;
				
			case HUMIDITY:
				// Map the random number to the humidity range [30, 90]%
				rand = call Random.rand16();
				value = (uint8_t)((rand % 61) + 30);
				//dbg("radio", "computed humidity value: %d\n", value);
				break;
				
			case LUMINOSITY:
			
				// Map the random number to the luminosity range [0, 255] lux
				value = (uint8_t)(call Random.rand16() % 255);
				//dbg("radio", "computed luminosity value: %d\n", value);
				break;
				
			default:
				break;
		}
		return value;
	}
  	
  	
  	event void Boot.booted() 
  	{
  		queue = (queue_t*)malloc(sizeof(queue_t));
  		queueInit(queue);
    	dbg("boot","Application booted\n");
    	call AMControl.start();
  	}

  	event void AMControl.startDone(error_t err)
  	{
    	if(err == SUCCESS) {
    	
    		if(TOS_NODE_ID == 1) {	
    			dbg("radio","PAN Coordinator: Radio ON.\n");
    			
      		} else {	
      				dbg("radio","NODE %d: Radio ON.\n", TOS_NODE_ID - 1);
				}      	
      		call MilliTimer.startPeriodic(250);
      		
    	} else {
      		dbgerror("radio", "Radio start failed, retrying...\n");
      		call AMControl.start();
    	}
  	}

  	event void AMControl.stopDone(error_t err)
  	{
  		dbg("boot", "Radio stopped.\n");
  	}
  	
  	
  	event void MilliTimer.fired()
  	{
		if (locked) return;
			else {
		  		msg_t* msg = (msg_t*)call Packet.getPayload(&packet, sizeof(msg_t));
		  		
		  		if(msg == NULL) {
					return;
		  		}
		  		// Sending a CONN to PAN
		  		if(TOS_NODE_ID != 1 && !connReceived[TOS_NODE_ID - 2])
		  		{
		  			msg -> sender = TOS_NODE_ID;
		  			msg -> type = 0; // CONN MSG TYPE
		  			msg -> destination = 1; // PAN Coordinator destination
		  			
		  			call AMSend.send(msg -> destination, &packet, sizeof(msg_t));
					dbg("radio_send", "NODE %d: Sending CONN message to the PAN Coordinator...\n", TOS_NODE_ID - 1);	
		  		}
			}
  	}

  	event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len)
  	{
    	if (len != sizeof(msg_t)) return;
    		else
    		{
    			msg_t* msg = (msg_t*)payload;
    			
    			// Node different from the PAN Coordinator
    			if(TOS_NODE_ID != 1)
    			{
    				// CONNACK received
    				if(msg -> type == 1 && !connAckReceived[TOS_NODE_ID - 2]) 
    				{
    				
    					msg_t* msg = (msg_t*)call Packet.getPayload(&packet, sizeof(msg_t));
						dbg("radio_rec", "NODE %d: CONNACK received. Connection successful.\n", TOS_NODE_ID - 1);
						connAckReceived[TOS_NODE_ID - 2] = TRUE;
						
						// Preparing the SUB msg...
						
						// SUB topic chosen from the array of subscriptions.
						msg -> topic = topicSubscriptions[TOS_NODE_ID - 2]; 
						
  						msg -> type = 2; // SUB TYPE
						msg -> destination = 1;
						msg -> sender = TOS_NODE_ID;
						
						switch(msg -> topic){
							case 0: // TEMPERATURE
								dbg("radio_send", "NODE %d: Sending a SUB to TEMPERATURE topic...\n", TOS_NODE_ID - 1);
								break;
							case 1: //HUMIDITY
								dbg("radio_send", "NODE %d: Sending a SUB to HUMIDITY topic...\n", TOS_NODE_ID - 1);
								break;
							case 2: //LUMINOSITY
								dbg("radio_send", "NODE %d: Sending a SUB to LUMINOSITY topic...\n", TOS_NODE_ID - 1);
								break;
							default:
								break;
						}
						
						call AMSend.send(msg -> destination, &packet, sizeof(msg_t));
					}
					
					
					// SUBACK received
					if(msg -> type == 3 && !subAckReceived[TOS_NODE_ID - 2])
					{	
						switch(msg -> topic){
							case TEMPERATURE: // TEMPERATURE
								dbg("radio_rec", "NODE %d: SUBACK received. I am subscribed to TEMPERATURE topic.\n", TOS_NODE_ID - 1);
								break;
							case HUMIDITY: // HUMIDITY
								dbg("radio_rec", "NODE %d: SUBACK received. I am subscribed to HUMIDITY topic.\n", TOS_NODE_ID - 1);
								break;
							case LUMINOSITY: // LUMINOSITY
								dbg("radio_rec", "NODE %d: SUBACK received. I am subscribed to LUMINOSITY topic.\n", TOS_NODE_ID - 1);
								break;
							default:
								break;
						}

						subAckReceived[TOS_NODE_ID - 2] = TRUE;
						
					}
					
					
					if(connAckReceived[TOS_NODE_ID - 2] && subAckReceived[TOS_NODE_ID - 2])
					{ 
						msg_t* msg = (msg_t*)call Packet.getPayload(&packet, sizeof(msg_t));
						
						msg -> topic = topicSubscriptions[TOS_NODE_ID - 2]; //PUB only for the topic the node is subscribed to
						
						// creating realstic values for temperature, luminosity and humidity
						
						switch(msg -> topic){
							case TEMPERATURE: //TEMPERATURE
								msg -> data = generateRandomValue(TEMPERATURE); //Random Temperature between 0 ° C and 40° C
								dbg("radio_send", "NODE %d: Sending a PUB to TEMPERATURE topic with payload: %d°C\n", TOS_NODE_ID - 1, msg -> data);
								break;
							
							case HUMIDITY: //HUMIDITY
								msg -> data = generateRandomValue(HUMIDITY); //Random Humidity between 30% and 90%
								dbg("radio_send", "NODE %d: Sending a PUB to HUMIDITY topic with payload: %d%\n", TOS_NODE_ID - 1, msg -> data);
								break;
								
							case LUMINOSITY: //LUMINOSITY
								msg -> data = generateRandomValue(LUMINOSITY); //Random Luminosity between 0 and 255 lux
								dbg("radio_send", "NODE %d: Sending a PUB to LUMINOSITY topic with payload: %d lux\n", TOS_NODE_ID - 1, msg -> data);
								break;
								
							default:
								break;
						}
						
     					msg -> type = 4; // PUB TYPE
   						msg -> destination = 1;
  						msg -> sender = TOS_NODE_ID;
  						
						call AMSend.send(1, &packet, sizeof(msg_t));
					}
    			}
    			
    			
    			if(TOS_NODE_ID == 1) // PAN Coordinator node
    			{
    				// CONN received, need to send a CONNACK
    				if(msg -> type == 0)
					{
    					dbg("radio_rec", "PAN Coordinator: received CONN from node: %d\n", msg -> sender - 1);
   		 				connReceived[(msg -> sender) - 2] = TRUE;
   		 				
    					dbg("radio_send", "PAN Coordinator: sending CONNACK to node: %d...\n", msg -> sender - 1);	
    					
    					msg -> type = 1; // CONNACK TYPE
    					msg -> destination = msg -> sender;
    					msg -> sender = 1;
    					
    					
    					call AMSend.send(msg -> destination, bufPtr, sizeof(msg_t));
    					
    	 			}
    	 			
    	 			// SUB received, need to send a SUBACK
    				if(msg -> type == 2)
    				{
    					dbg("radio_rec", "PAN Coordinator: received SUB from node: %d\n", msg -> sender - 1);
    					subReceived[(msg -> sender) - 2] = TRUE;
    					
    					dbg("radio_send", "PAN Coordinator: sending SUBACK to node: %d...\n", msg -> sender - 1);
    					
    						
    					msg -> type = 3; // SUBACK TYPE
    					msg -> destination = msg -> sender;
    					msg -> sender = 1;
    					
    					
						call AMSend.send(msg -> destination, bufPtr, sizeof(msg_t));
						
    	 			}
    	 			
    	 			// PUB received, need to send a PUBACK
    	 			if(msg -> type == 4)
    				{	
    					switch(msg -> topic){
    						
    						case TEMPERATURE:
    							dbg("radio_rec", "PAN Coordinator: PUB received from node %d to topic TEMPERATURE with payload: %d°C\n", msg -> sender - 1, msg -> data);
    							break;
    						
    						case HUMIDITY: 
    							dbg("radio_rec", "PAN Coordinator: PUB received from node %d to topic HUMIDITY with payload: %d%\n", msg -> sender - 1, msg -> data);
    							break;
    							
    						case LUMINOSITY: 
    							dbg("radio_rec", "PAN Coordinator: PUB received from node %d to topic LUMINOSITY with payload: %d lux\n", msg -> sender - 1, msg -> data);
    							break;
    							
    						default: 
    							break;
    					}
    					enqueue(queue, msg);
    	 			}
    	 			
	 				// Take message from queue buffer
					// printQueue(queue);
					if(peek(queue, msg)){
						
				 		// Check again whether msg is a PUB message
						if(msg -> type == 4) 
				 		{
				 			// for each node, checking whether it is subscribed to the msg's topic and then forwarding the message
					
							for (i = 0; i < 8; i++) 
							{ 
								if(topicSubscriptions[i] == msg -> topic && subAckReceived[i] && i != msg -> sender - 2)
								{
									dbg("radio_rec", "PAN Coordinator: Forwarding PUB to the subscribed node: %d...\n", i + 1);
									call AMSend.send(i + 1, bufPtr, sizeof(msg_t));	
								}	
							}
				 		
							dbg("radio_rec", "PAN Coordinator: Sending PUB messages to Node-RED. Contains: topic: %d, data: %d\n", msg->topic, msg->data);
							// Send the message to Node-RED TCP node
						
							// Create socket
							sockfd = socket(AF_INET, SOCK_STREAM, 0);
							if(sockfd == -1)
							{
								dbg("error", "PAN Coordinator: Socket creation failed!\n");
								return bufPtr;
							}
						
							// Set server address
							servaddr.sin_family = AF_INET;
							servaddr.sin_addr.s_addr = inet_addr(SERVER_IP);
							servaddr.sin_port = htons(SERVER_PORT);
						
							// Connect to the server
							if(connect(sockfd, (struct sockaddr*)&servaddr, sizeof(servaddr)) != 0)
							{
								dbg("error", "PAN Coordinator: Connection with the server failed!\n");
								close(sockfd);
								return bufPtr;
							}
						
							// Send the message
							if(send(sockfd, msg, sizeof(msg_t), 0) == -1)
							{
								dbg("error", "PAN Coordinator: Failed to send message!\n");
								return bufPtr;
							}
							
							//Dequeueing the just sent message
							dequeue(queue);
						
							close(sockfd);
							sleep(10); 
						}	
					}
    			}
    		}
    	return bufPtr;
	}

	event void AMSend.sendDone(message_t* bufPtr, error_t error) // Handle retransmission if packets get lost
  	{
  		msg_t* msg = (msg_t*)call Packet.getPayload(&packet, sizeof(msg_t));
  		if(&packet == bufPtr && error == SUCCESS)
  		{
      		locked = TRUE;	
  		}
  		
  		if((!connReceived[TOS_NODE_ID - 2] || !connAckReceived[TOS_NODE_ID - 2])  && TOS_NODE_ID != 1) 
  		{	
  			// If I'm not the PAN and I don't have received the CONNACK or my CONN message did not arrived to the PAN, I have to resend it
			dbg("radio_send", "NODE %d: CONN Packet lost. Sending again a CONN to PAN...\n", TOS_NODE_ID - 1);	
			msg -> type = 0; // CONN TYPE
   			msg -> destination = 1;
   			msg -> sender = TOS_NODE_ID;
			call AMSend.send(msg -> destination, &packet, sizeof(msg_t));
    	}
    	
    	if((!subReceived[TOS_NODE_ID - 2] || !subAckReceived[TOS_NODE_ID - 2]) && TOS_NODE_ID != 1 && connAckReceived[TOS_NODE_ID - 2]) 
  		{	
			// I am not the PAN and connected to the PAN. I do not have received the SUBACK or my SUB did not arrived to the PAN.
			
			// going back to the topic the node first requested	
			switch(topicSubscriptions[TOS_NODE_ID - 2]){
				case 0: // TEMPERATURE
					dbg("radio_send", "NODE %d: Packet lost. Sending again a SUB to PAN for TEMPERATURE topic\n", TOS_NODE_ID - 1);
					break;
					
				case 1: // HUMIDITY
					dbg("radio_send", "NODE %d: Packet lost. Sending again a SUB to PAN for HUMIDITY topic.\n", TOS_NODE_ID - 1);
					break;
					
				case 2: // LUMINOSITY
					dbg("radio_send", "NODE %d: Packet lost. Sending again a SUB to PAN for LUMINOSITY topic.\n", TOS_NODE_ID - 1);
					break;
					
				default:
					break;
			}			

			msg -> topic = topicSubscriptions[TOS_NODE_ID - 2];
			msg -> type = 2; // SUB TYPE
			msg -> destination = 1;
		   	msg -> sender = TOS_NODE_ID;
			call AMSend.send(msg -> destination, &packet, sizeof(msg_t));
		}
  	}
} 

// END implementation
