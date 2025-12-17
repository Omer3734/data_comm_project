import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NetComm Sim',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Varsayılan IP (Kendi bilgisayarınızın IP'si ile değiştirin veya UI'dan girin)
  final TextEditingController _ipController = TextEditingController(text: "192.168.1.XX");
  final TextEditingController _msgController = TextEditingController(text: "HELLO");

  // Uygulama Modu (Sender / Receiver)
  bool _isSender = true;

  // Loglar
  List<Map<String, String>> _logs = [];
  String _status = "Hazır";
  bool _isLoading = false;

  // ----------------------------------------------------------------
  // HAMMING ALGORİTMASI (DART VERSİYONU)
  // ----------------------------------------------------------------

  // 4 bit için Hamming parity hesapla (P1, P2, P3)
  int _calcHammingBits(int nibble) {
    int d1 = (nibble >> 3) & 1;
    int d2 = (nibble >> 2) & 1;
    int d3 = (nibble >> 1) & 1;
    int d4 = nibble & 1;

    int p1 = d1 ^ d2 ^ d4;
    int p2 = d1 ^ d3 ^ d4;
    int p3 = d2 ^ d3 ^ d4;

    return (p1 << 2) | (p2 << 1) | p3;
  }

  // Metni kodla (Encoder)
  String _hammingEncoder(String text) {
    String controlHex = "";
    for (int i = 0; i < text.length; i++) {
      int val = text.codeUnitAt(i);
      int upper = (val >> 4) & 0xF;
      int lower = val & 0xF;

      int pUp = _calcHammingBits(upper);
      int pLow = _calcHammingBits(lower);

      controlHex += pUp.toRadixString(16).toUpperCase();
      controlHex += pLow.toRadixString(16).toUpperCase();
    }
    return controlHex;
  }

  // Doğrulama (Decoder)
  String _hammingVerifier(String data, String incomingControl) {
    String computedControl = _hammingEncoder(data);

    if (computedControl == incomingControl) {
      return "SUCCESS";
    }

    // Basit Hata Analizi
    int diff = 0;
    if (computedControl.length != incomingControl.length) return "CORRUPTED (Length Mismatch)";

    for(int i=0; i<computedControl.length; i++){
      if(computedControl[i] != incomingControl[i]) diff++;
    }

    if (diff > 2) return "CORRUPTED (Burst Error)";
    return "CORRUPTED (Bit Flip)";
  }

  // ----------------------------------------------------------------
  // AĞ İŞLEMLERİ
  // ----------------------------------------------------------------

  // GÖNDERİCİ FONKSİYONU
  Future<void> _sendData() async {
    setState(() { _isLoading = true; _status = "Bağlanıyor..."; });

    try {
      String ip = _ipController.text;
      String text = _msgController.text;
      String control = _hammingEncoder(text);
      String packet = "$text|HAMMING|$control";

      // Server'a bağlan
      Socket socket = await Socket.connect(ip, 65432, timeout: const Duration(seconds: 5));

      // Gönder
      socket.write(packet);
      await socket.flush();
      socket.destroy();

      _addLog("Giden", "$text (Kod: $control)", true);
      setState(() { _status = "Veri Gönderildi!"; });

    } catch (e) {
      setState(() { _status = "Hata: $e"; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  // ALICI FONKSİYONU
  Future<void> _listenData() async {
    setState(() { _isLoading = true; _status = "Server bekleniyor..."; });

    try {
      String ip = _ipController.text;
      Socket socket = await Socket.connect(ip, 65432, timeout: const Duration(seconds: 10));

      setState(() { _status = "Bağlandı! Veri bekleniyor..."; });

      socket.listen(
            (List<int> event) {
          String packet = utf8.decode(event);
          List<String> parts = packet.split('|');

          if (parts.length >= 3) {
            String data = parts[0];
            String method = parts[1];
            String control = parts[2];

            String result = _hammingVerifier(data, control);
            bool isSuccess = result == "SUCCESS";

            _addLog(
                "Gelen ($method)",
                "Veri: $data\nDurum: $result\nKod: $control",
                isSuccess
            );

            setState(() { _status = "Paket Alındı: $result"; });
          }
          socket.destroy();
        },
        onError: (e) => setState(() { _status = "Hata: $e"; }),
        onDone: () => setState(() { _isLoading = false; }),
      );

    } catch (e) {
      setState(() { _status = "Bağlantı Hatası: $e"; _isLoading = false; });
    }
  }

  void _addLog(String title, String desc, bool isSuccess) {
    setState(() {
      _logs.insert(0, {
        "title": title,
        "desc": desc,
        "color": isSuccess ? "green" : "red"
      });
    });
  }

  // ----------------------------------------------------------------
  // ARAYÜZ (UI)
  // ----------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Data Communication Projesi"),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: Icon(_isSender ? Icons.upload : Icons.download),
            onPressed: () {
              setState(() {
                _isSender = !_isSender;
                _logs.clear();
                _status = "Mod Değiştirildi";
              });
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // IP Giriş Alanı
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: "Server IP Adresi (PC)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.computer),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),

            // Mod Göstergesi
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: _isSender ? Colors.blue.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _isSender ? Colors.blue : Colors.orange),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isSender ? Icons.send : Icons.move_to_inbox, color: _isSender ? Colors.blue : Colors.orange),
                  const SizedBox(width: 10),
                  Text(
                    _isSender ? "MOD: GÖNDERİCİ (Client 1)" : "MOD: ALICI (Client 2)",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Gönderici veya Alıcı Arayüzü
            if (_isSender) ...[
              TextField(
                controller: _msgController,
                decoration: const InputDecoration(
                  labelText: "Gönderilecek Metin",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _sendData,
                  icon: const Icon(Icons.send),
                  label: const Text("VERİYİ GÖNDER"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _listenData,
                  icon: const Icon(Icons.wifi_tethering),
                  label: Text(_isLoading ? "BEKLENİYOR..." : "BAĞLAN VE DİNLE"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                ),
              ),
            ],

            const SizedBox(height: 20),
            Text(_status, style: const TextStyle(color: Colors.grey)),
            const Divider(),

            // Log Listesi
            Expanded(
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  Color c = log['color'] == 'green' ? Colors.greenAccent : Colors.redAccent;
                  return Card(
                    color: c.withValues(alpha: 0.1),
                    child: ListTile(
                      leading: Icon(
                        log['color'] == 'green' ? Icons.check_circle : Icons.error,
                        color: c,
                      ),
                      title: Text(log['title']!, style: TextStyle(color: c, fontWeight: FontWeight.bold)),
                      subtitle: Text(log['desc']!),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}