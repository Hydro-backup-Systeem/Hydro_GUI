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
  List<String> driverMessages = []; // Messages from the driver
  List<String> appMessages = []; // Messages from the app

  final ScrollController _appScrollController = ScrollController(); // Separate controller for app messages
  final ScrollController _driverScrollController = ScrollController(); // Separate controller for driver messages

  @override
  void initState() {
    super.initState();
    runLoraExecutable();
    _connectToServer();
  }

  Future<void> runLoraExecutable() async { // Function to run the lora executable
    try {
      final process = await Process.start(
        '/home/hydro/project/backend/Hydro-LoRa-Shield/lora', // Path to the lora executable
        [],
        workingDirectory: Directory.current.path,
        runInShell: true,
      );

      process.stdout.transform(SystemEncoding().decoder).listen((line) {
        print('lora output: $line');
        // setState(() {
        //   receivedMessages.add('LoRa: $line'); // Add LoRa output to messages
        // });
      });

      process.stderr.transform(SystemEncoding().decoder).listen((line) {
        print('lora stderr: $line');
        // setState(() {
        //   receivedMessages.add('LoRa Error: $line'); // Add LoRa errors to messages
        // });
      });

      final exitCode = await process.exitCode;
      print('lora exited with code: $exitCode');
    } catch (e) {
      print('Error running lora executable: $e');
      // setState(() {
      //   receivedMessages.add('Error running LoRa: $e');
      // });
    }
  }

  void _connectToServer() async { // Function to connect to the server
    int retryCount = 0;
    const maxRetries = 10; // Maximum number of retries
    const retryDelay = Duration(seconds: 3); // Delay between retries

    while (retryCount < maxRetries) {
      try {
        print('Attempting to connect (attempt ${retryCount + 1}/$maxRetries)...');
        _socket = await Socket.connect('127.0.0.1', 8080);
        print('Connected to server');
        setState(() {
          appMessages.add('Connection to driver is ready to go!');
        });

        _socket!.listen(
          (data) {
            try {
              String message = const Utf8Decoder().convert(data);
              print('RECEIVED FROM DRIVER: $message');
              setState(() {
                driverMessages.add('RECEIVED FROM DRIVER: $message');
              });
            } catch (e) {
              print('Decoding error: $e');
            }
          },
          onError: (error) {
            print('Socket error: $error');
            _socket?.destroy();
            _attemptReconnect();
          },
          onDone: () {
            print('Server disconnected');
            _socket?.destroy();
            _attemptReconnect();
          },
        );
        break; // Exit the loop if connection is successful
      } catch (e) {
        retryCount++;
        print('Connection attempt $retryCount failed: $e');

        if (retryCount < maxRetries) {
          await Future.delayed(retryDelay);
        } else {
          print('Could not connect to server after $maxRetries attempts');
          setState(() {
            //receivedMessages.add('Failed to connect after $maxRetries attempts');
            appMessages.add('SOCKET CRASHED! Please restart the app.');
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

  // void _scrollToBottom() {
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     if (_scrollController.hasClients) {
  //       _scrollController.animateTo(
  //         _scrollController.position.maxScrollExtent,
  //         duration: const Duration(milliseconds: 300),
  //         curve: Curves.easeOut,
  //       );
  //     }
  //   });
  // }

  void _sendMessage() { // Send message to PI
    if (_socket != null && _controller.text.isNotEmpty) {
      _socket!.write(_controller.text);
      print('Sent: ${_controller.text}');
      setState(() {
        appMessages.add('Sent: $_controller'); // Add to app messages
      });
      _controller.clear();
      //_scrollToBottom(); // Auto-scroll after sending a message
    }
  }

  void _sendPresetMessage(String message) { // Send preset message to PI
    if (_socket != null) {
      _socket!.write(message);
      print('Sent preset: $message');
      setState(() {
        appMessages.add('Sent Preset: $message');
      });
      //_scrollToBottom(); // Auto-scroll after sending preset message
    }
  }

  void _sendFlagMessage(String message) { // Send flag message to PI
    if (_socket != null) {
      _socket!.write(message);
      print('Sent preset: $message');
      setState(() {
        appMessages.add('Sent Flag: $message');
      });
      //_scrollToBottom(); // Auto-scroll after sending preset message
    }
  }

  Widget _buildFlagButton(String label, IconData icon, Color color, String code) { // Build flag button
    return ElevatedButton.icon(
      onPressed: () => _sendFlagMessage(code),
      icon: Icon(icon, color: Colors.white),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );
    }

  @override
  void dispose() {
    _appScrollController.dispose(); 
    _driverScrollController.dispose();
    _socket?.destroy();
    super.dispose();
  }

@override
Widget build(BuildContext context) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text('Hydro Backup Communication System'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                // LEFT SIDE: Preset Messages & Flags
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DICTONARY PRESETS',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        ...[
                          "Box Box",
                          "Try harder in sector 2",
                          "You are now in pole position"
                        ].map(
                          (msg) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => _sendPresetMessage(msg),
                                child: Text(msg, textAlign: TextAlign.center),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('FLAGS',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 300,
                          child: GridView.count(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 3.5,
                            children: [
                              _buildFlagButton('Blue Flag', Icons.flag, Colors.blue, 'flag1'),
                              _buildFlagButton('Meatball Flag', Icons.flag, Colors.orange, 'flag2'),
                              _buildFlagButton('Yellow Flag', Icons.flag, const Color.fromARGB(255, 201, 184, 36), 'flag3'),
                              _buildFlagButton('Black Flag', Icons.flag, Colors.black, 'flag4'),
                              _buildFlagButton('Green Flag', Icons.flag, Colors.green, 'flag5'),
                              _buildFlagButton('Red Flag', Icons.flag, Colors.red, 'flag6'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                VerticalDivider(thickness: 1),
                // RIGHT SIDE: Received messages
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Messages from App:',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Scrollbar(
                                thumbVisibility: true,
                                controller: _appScrollController,
                                child: ListView.builder(
                                  controller: _appScrollController,
                                  itemCount: appMessages.length,
                                  itemBuilder: (context, index) {
                                    return ListTile(
                                      title: Text(appMessages[index]),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text('Messages from Driver:',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Scrollbar(
                                thumbVisibility: true,
                                controller: _driverScrollController,
                                child: ListView.builder(
                                  controller: _driverScrollController,
                                  itemCount: driverMessages.length,
                                  itemBuilder: (context, index) {
                                    return ListTile(
                                      title: Text(driverMessages[index]),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // BOTTOM: Input & Send
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (value) {
                        _sendMessage(); // Trigger the send button functionality
                        _controller.clear(); // Clear the text field after sending
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Type message to send to driver',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (_controller.text.isNotEmpty) {
                        _sendMessage(); // Send the message
                        _controller.clear(); // Clear the text field after sending
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                    ),
                    child: Text('Send'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}