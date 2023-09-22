# IoT_Project_2023 Project 1 - LIGHTWEIGHT PUBLISH-SUBSCRIBE APPLICATION PROTOCOL
Internet Of Things Course Project. Politecnico Di Milano AY 2022/2023

## Specifications
Design and implement in TinyOS a lightweight publishsubscribe application protocol similar to MQTT and test it with simulations
on a star-shaped network topology composed of 8 client nodes connected to a PAN coordinator. The PAN coordinator acts as an MQTT broker.

The following features need to be implemented:
1. Connection: upon activation, each node sends a CONNECT message to the PAN coordinator. The PAN coordinator replies with a CONNACK message. If the PAN coordinator receives messages from not yet connected nodes, such messages are ignored. Be sure to handle retransmissions if msgs get lost (retransmission if CONN or CONNACK is lost).
2. Subscribe: after connection, each node can subscribe to one among these three topics: TEMPERATURE, HUMIDITY, LUMINOSITY. In order to subscribe, a node sends a SUBSCRIBE message to the PAN coordinator, containing its node ID and the topics it wants to subscribe to (use integer topics). Assume the subscriber always use QoS=0 for subscriptions. The subscribe message is acknowledged by the PANC with a SUBACK message. (handle retransmission if SUB or SUBACK is lost)
3. Publish: each node can publish data on at most one of the three aforementioned topics. The publication is performed through a PUBLISH message with the following fields: topic name, payload (assume that always QoS=0). When a node publishes a message on a topic, this is received by the PAN and forwarded to all nodes that have subscribed to a particular topic.
4. Test the implementation in the simulation environment in TOSSIM, with at least 3 nodes subscribing to more than 1 topic. The payload of PUBLISH messages on all topics is a random number.
5. The PAN Coordinator (Broker node) should be connected to NodeRED, and periodically transmit data received on the topics to ThingsSpeak through MQTT. Thingspeak must show one chart for each topic on a public channel.

## Tools and languages
- TinyOS 
  - nesC
- Tossim
  - Python
- Node-RED
- ThingSpeak

## How to run it
1. Clone this repository
2. Open the terminal
3. Install nodeRED on your system if you do not have it and then run the `node-red` command
4. Open your browser and reach `localhost:1880`
5. Import the Node-RED flow from `/Project/IOTP1_Node-Red_flow.pdf`
6. Insert the credentials provided in the `/Project/thingspeak_credentials.txt` file double-clicking on the mqtt node, then on the pencil icon. Then, please insert the client-ID and in the connection part and Username and Password in the security part.   
7. Open another terminal window
8. Move to `/tinyos_code`
9. Launch this command `make micaz sim`
10. Once the command has been executed, launch `RunSimulationScript.py`
11. Open [the ThingSpeak public channel](https://thingspeak.com/channels/2232252) with the credentials in order to have access to the real-time charts of the data contained in the motes' PUBLISH messages.

## Report
A detailed report about the project development can be found in the .pdf file `IOT_Project_10488414_10812073.pdf`.

## Credits
Developed by Claudio Eutizi (PERSON_ID: 10812073) and Gabriele Perego (PERSON_ID: 10488414)