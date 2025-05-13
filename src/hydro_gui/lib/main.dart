import 'package:flutter/material.dart';
import 'dart:io'; // For sockets
import 'dart:convert'; // For utf8 encoding

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
    //_connectToServer();
    //Start LoRa executable first
    runLoraExecutable();
    _connectToServer();
  }

  Future<void> runLoraExecutable() async {
  try {
    final process = await Process.start(
      '/home/hydro/project/backend/Hydro-LoRa-Shield/lora', // Path to the lora executable
      [],
      workingDirectory: Directory.current.path,
      runInShell: true,
    );

    process.stdout.transform(SystemEncoding().decoder).listen((line) {
      print('lora stdout: $line');
      setState(() {
        receivedMessages.add('LoRa: $line'); // Add LoRa output to messages
      });
    });

    process.stderr.transform(SystemEncoding().decoder).listen((line) {
      print('lora stderr: $line');
      setState(() {
        receivedMessages.add('LoRa Error: $line'); // Add LoRa errors to messages
      });
    });

    final exitCode = await process.exitCode;
    print('lora exited with code: $exitCode');
  } catch (e) {
    print('Error running lora executable: $e');
    setState(() {
      receivedMessages.add('Error running LoRa: $e');
    });
  }
  }

  void _connectToServer() async {
    int retryCount = 0;
    const maxRetries = 10; // Maximum number of retries
    const retryDelay = Duration(seconds: 3); // Delay between retries

    while (retryCount < maxRetries) {
      try {
        print('Attempting to connect (attempt ${retryCount + 1}/$maxRetries)...');
        _socket = await Socket.connect('127.0.0.1', 8080);
        print('Connected to server');
        setState(() {
          receivedMessages.add('Connected to server successfully');
        });

        // Start listening to the socket
        _socket!.listen(
          (data) {
            try {
              String message = const Utf8Decoder().convert(data);
              print('Received (utf8): $message');
              setState(() {
                receivedMessages.add('Received: $message');
              });
            } catch (e) {
              print('Decoding error: $e');
              setState(() {
                receivedMessages.add('Received binary data: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ').toUpperCase()}');
              });
            }
          },
          onError: (error) {
            print('Socket error: $error');
            setState(() {
              receivedMessages.add('Socket error: $error');
            });
            _socket?.destroy();
            _attemptReconnect();
          },
          onDone: () {
            print('Server disconnected');
            setState(() {
              receivedMessages.add('Server disconnected - attempting to reconnect...');
            });
            _socket?.destroy();
            _attemptReconnect();
          },
        );
        break; // Exit the loop if connection is successful
      } catch (e) {
        retryCount++;
        print('Connection attempt $retryCount failed: $e');
        setState(() {
          receivedMessages.add('Connection attempt $retryCount failed: $e');
        });

        if (retryCount < maxRetries) {
          setState(() {
            receivedMessages.add('Retrying in ${retryDelay.inSeconds} seconds...');
          });
          await Future.delayed(retryDelay);
        } else {
          print('Could not connect to server after $maxRetries attempts');
          setState(() {
            receivedMessages.add('Failed to connect after $maxRetries attempts');
            receivedMessages.add('Please check if the server is running and try restarting the app');
          });
        }
      }
    }
  }

  void _attemptReconnect() {
    Future.delayed(Duration(seconds: 3), () {
      print('Attempting to reconnect...');
      _connectToServer();
    });
  }

  void _sendMessage() { // Send message to PI
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
