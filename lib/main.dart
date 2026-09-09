import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

const _purple = Color(0xFF6548D9);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: const FirebaseOptions(
    apiKey: 'AIzaSyAsVw0MRn6Y6PQ6iYO0nVWUtVWgDbRwsAE',
    appId: '1:632899048727:android:9dc9b07c2b78fc65ae9352',
    messagingSenderId: '632899048727',
    projectId: 'family-life-36bd1',
    storageBucket: 'family-life-36bd1.firebasestorage.app',
  ));
  runApp(const FamilyLifeRoot());
}

class FamilyLifeRoot extends StatelessWidget {
  const FamilyLifeRoot({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Family Life €',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: _purple),
    ),
    home: const AuthGate(),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final email = TextEditingController();
  final password = TextEditingController();

  bool login = true;
  bool loading = false;
  String? error;

  Future<void> _submit() async {
    setState(() => loading = true);

    try {
      if (login) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      } else {
        final c = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );

        await FirebaseFirestore.instance
            .collection('users')
            .doc(c.user!.uid)
            .set({
          'email': email.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message ?? 'Errore di accesso');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (s.hasData) {
            return FamilyGate(user: s.data!);
          }

          return Scaffold(
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text(
                        '👨‍👩‍👦',
                        style: TextStyle(fontSize: 52),
                      ),
                      const Text(
                        'Family Life €',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        login
                            ? 'Accedi alla tua famiglia'
                            : 'Crea il tuo account',
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: password,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password (minimo 6 caratteri)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: loading ? null : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                        ),
                        child: loading
                            ? const CircularProgressIndicator()
                            : Text(login ? 'Accedi' : 'Registrati'),
                      ),
                      TextButton(
                        onPressed: () => setState(() => login = !login),
                        child: Text(
                          login
                              ? 'Non hai un account? Registrati'
                              : 'Hai già un account? Accedi',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
}

class FamilyGate extends StatelessWidget {
  const FamilyGate({
    super.key,
    required this.user,
  });

  final User user;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, s) {
          if (!s.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final data = s.data!.data();
          final familyId = data?['familyId'] as String?;

          if (familyId == null) {
            return FamilySetup(user: user);
          }

          return FamilyLifeApp(
            user: user,
            familyId: familyId,
          );
        },
      );
}

class FamilySetup extends StatefulWidget {
  const FamilySetup({
    super.key,
    required this.user,
  });

  final User user;

  @override
  State<FamilySetup> createState() => _FamilySetupState();
}

class _FamilySetupState extends State<FamilySetup> {
  final name = TextEditingController(text: 'La mia famiglia');
  final code = TextEditingController();

  bool loading = false;

  Future<void> create() async {
    setState(() => loading = true);

    final db = FirebaseFirestore.instance;
    final ref = db.collection('families').doc();
    final invite = ref.id.substring(0, 6).toUpperCase();

    await ref.set({
      'name': name.text.trim().isEmpty
          ? 'La mia famiglia'
          : name.text.trim(),
      'ownerId': widget.user.uid,
      'members': [widget.user.uid],
      'inviteCode': invite,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await db.collection('users').doc(widget.user.uid).set({
      'email': widget.user.email,
      'familyId': ref.id,
    }, SetOptions(merge: true));

    if (mounted) setState(() => loading = false);
  }

  Future<void> join() async {
    setState(() => loading = true);

    final q = await FirebaseFirestore.instance
        .collection('families')
        .where(
          'inviteCode',
          isEqualTo: code.text.trim().toUpperCase(),
        )
        .limit(1)
        .get();

    if (q.docs.isEmpty) {
      if (mounted) {
        setState(() => loading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Codice famiglia non trovato'),
          ),
        );
      }
      return;
    }

    final id = q.docs.first.id;

    await q.docs.first.reference.update({
      'members': FieldValue.arrayUnion([widget.user.uid]),
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .set({
      'email': widget.user.email,
      'familyId': id,
    }, SetOptions(merge: true));

    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                '👨‍👩‍👦 Benvenuto!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Crea una famiglia oppure unisciti a quella del tuo partner.',
              ),
              const SizedBox(height: 24),
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Nome famiglia',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: loading ? null : create,
                child: const Text('Crea la mia famiglia'),
              ),
              const Divider(height: 40),
              TextField(
                controller: code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Codice invito
                  class AddPage extends StatefulWidget {
  const AddPage({
    super.key,
    required this.familyId,
    required this.user,
    required this.onSaved,
  });

  final String familyId;
  final User user;
  final VoidCallback onSaved;

  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  final amount = TextEditingController();
  final title = TextEditingController();
  final merchant = TextEditingController();
  final receiptDate = TextEditingController();

  String kind = 'Familiare';
  String payer = 'Enzo';

  bool income = false;
  bool saving = false;
  bool analysing = false;

  XFile? receipt;
  List<String> receiptItems = [];

  Future<void> pickReceipt(ImageSource source) async {
    final f = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
    );

    if (f != null && mounted) {
      setState(() => receipt = f);
    }
  }

  Future<void> analyseReceipt() async {
    if (receipt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prima allega uno scontrino'),
        ),
      );
      return;
    }

    setState(() => analysing = true);

    final parsed = await ReceiptOcrService.analyse(
      receipt!.path,
    );

    if (!mounted) return;

    setState(() => analysing = false);

    final result =
        await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => ReceiptAnalysisPage(
          imagePath: receipt!.path,
          initialTotal: parsed.total.isNotEmpty
              ? parsed.total
              : amount.text,
          initialMerchant: parsed.merchant.isNotEmpty
              ? parsed.merchant
              : merchant.text,
          initialDate: parsed.date.isNotEmpty
              ? parsed.date
              : receiptDate.text,
          initial
