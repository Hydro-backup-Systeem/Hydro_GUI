import 'package:flutter/material.dart';
import 'dart:io'; // For sockets

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  TextEditingController _controller = TextEditingController(); // Controller to get text input
  Socket? _socket;
  List<String> receivedMessages = [];

  @override
  void initState() {
    super.initState();
    _connectToServer();
  }

  void _connectToServer() async {
    try {
      _socket = await Socket.connect('127.0.0.1', 8080); // Replace with your server IP and port
      print('Connected to server');
      _socket!.listen(
        (data) {
          String message = String.fromCharCodes(data);
          print('Received: $message');
          setState(() {
            receivedMessages.add(message);
          });
        },
        onError: (error) {
          print('Socket error: $error');
          _socket?.destroy();
        },
        onDone: () {
          print('Server disconnected');
          _socket?.destroy();
        },
      );
    } catch (e) {
      print('Could not connect to server: $e');
    }
  }

  void _sendMessage() {
    if (_socket != null && _controller.text.isNotEmpty) {
      _socket!.write(_controller.text);
      print('Sent: ${_controller.text}');
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _socket?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Hide debug banner
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
          title: const Text('Hydro Backup Communication System'),
        ),
        body: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Enter Message',
                      ),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _sendMessage,
                      child: Text('Send Message'),
                    ),
                  ],
                ),
              ),
            ),
            VerticalDivider(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Incoming Messages:',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: ListView.builder(
                        itemCount: receivedMessages.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(receivedMessages[index]),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
