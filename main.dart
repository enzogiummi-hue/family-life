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
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Family Life €',
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: _purple)),
    home: const AuthGate(),
  );
}

class AuthGate extends StatefulWidget { const AuthGate({super.key}); @override State<AuthGate> createState()=>_AuthGateState(); }
class _AuthGateState extends State<AuthGate> {
  final email=TextEditingController(), password=TextEditingController(); bool login=true, loading=false; String? error;
  Future<void> _submit() async {
    setState(()=>loading=true); try {
      if(login) { await FirebaseAuth.instance.signInWithEmailAndPassword(email: email.text.trim(), password: password.text); }
      else { final c=await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email.text.trim(), password: password.text); await FirebaseFirestore.instance.collection('users').doc(c.user!.uid).set({'email':email.text.trim(),'createdAt':FieldValue.serverTimestamp()}); }
    } on FirebaseAuthException catch(e) { setState(()=>error=e.message ?? 'Errore di accesso'); } finally { if(mounted)setState(()=>loading=false); }
  }
  @override void dispose(){email.dispose();password.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>StreamBuilder<User?>(stream: FirebaseAuth.instance.authStateChanges(),builder:(context,s){
    if(s.connectionState==ConnectionState.waiting)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    if(s.hasData)return FamilyGate(user:s.data!);
    return Scaffold(body:SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(children:[
      const Text('👨‍👩‍👦',style:TextStyle(fontSize:52)), const Text('Family Life €',style:TextStyle(fontSize:32,fontWeight:FontWeight.bold)), const SizedBox(height:8), Text(login?'Accedi alla tua famiglia':'Crea il tuo account'), const SizedBox(height:28),
      TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email',border:OutlineInputBorder())), const SizedBox(height:12),
      TextField(controller:password,obscureText:true,decoration:const InputDecoration(labelText:'Password (minimo 6 caratteri)',border:OutlineInputBorder())), if(error!=null)Padding(padding:const EdgeInsets.only(top:10),child:Text(error!,style:const TextStyle(color:Colors.red))), const SizedBox(height:16),
      FilledButton(onPressed:loading?null:_submit,style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(54)),child:loading?const CircularProgressIndicator():Text(login?'Accedi':'Registrati')),
      TextButton(onPressed:()=>setState(()=>login=!login),child:Text(login?'Non hai un account? Registrati':'Hai già un account? Accedi'))
    ]))));
  });
}

class FamilyGate extends StatelessWidget { const FamilyGate({super.key,required this.user}); final User user;
  @override Widget build(BuildContext context)=>StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),builder:(context,s){
    if(!s.hasData)return const Scaffold(body:Center(child:CircularProgressIndicator())); final data=s.data!.data(); final familyId=data?['familyId'] as String?;
    if(familyId==null)return FamilySetup(user:user); return FamilyLifeApp(user:user,familyId:familyId);
  });
}

class FamilySetup extends StatefulWidget { const FamilySetup({super.key,required this.user}); final User user; @override State<FamilySetup> createState()=>_FamilySetupState(); }
class _FamilySetupState extends State<FamilySetup>{ final name=TextEditingController(text:'La mia famiglia'); final code=TextEditingController(); bool loading=false;
  Future<void> create() async { setState(()=>loading=true); final db=FirebaseFirestore.instance; final ref=db.collection('families').doc(); final invite=ref.id.substring(0,6).toUpperCase(); await ref.set({'name':name.text.trim().isEmpty?'La mia famiglia':name.text.trim(),'ownerId':widget.user.uid,'members':[widget.user.uid],'inviteCode':invite,'createdAt':FieldValue.serverTimestamp()}); await db.collection('users').doc(widget.user.uid).set({'email':widget.user.email,'familyId':ref.id},SetOptions(merge:true)); if(mounted)setState(()=>loading=false); }
  Future<void> join() async { setState(()=>loading=true); final q=await FirebaseFirestore.instance.collection('families').where('inviteCode',isEqualTo:code.text.trim().toUpperCase()).limit(1).get(); if(q.docs.isEmpty){if(mounted){setState(()=>loading=false);ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Codice famiglia non trovato')));}return;} final id=q.docs.first.id; await q.docs.first.reference.update({'members':FieldValue.arrayUnion([widget.user.uid])}); await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).set({'email':widget.user.email,'familyId':id},SetOptions(merge:true)); if(mounted)setState(()=>loading=false); }
  @override Widget build(BuildContext context)=>Scaffold(body:SafeArea(child:ListView(padding:const EdgeInsets.all(24),children:[const Text('👨‍👩‍👦 Benvenuto!',style:TextStyle(fontSize:28,fontWeight:FontWeight.bold)),const SizedBox(height:8),const Text('Crea una famiglia oppure unisciti a quella del tuo partner.'),const SizedBox(height:24),TextField(controller:name,decoration:const InputDecoration(labelText:'Nome famiglia',border:OutlineInputBorder())),const SizedBox(height:12),FilledButton(onPressed:loading?null:create,child:const Text('Crea la mia famiglia')),const Divider(height:40),TextField(controller:code,textCapitalization:TextCapitalization.characters,decoration:const InputDecoration(labelText:'Codice invito famiglia',border:OutlineInputBorder())),const SizedBox(height:12),OutlinedButton(onPressed:loading?null:join,child:const Text('Unisciti alla famiglia'))])));
}

class FamilyLifeApp extends StatefulWidget { const FamilyLifeApp({super.key,required this.user,required this.familyId}); final User user; final String familyId; @override State<FamilyLifeApp> createState()=>_FamilyLifeAppState(); }
class _FamilyLifeAppState extends State<FamilyLifeApp>{int tab=0; @override Widget build(BuildContext context){ final pages=[HomePage(familyId:widget.familyId,onAdd:()=>setState(()=>tab=2)),MovementsPage(familyId:widget.familyId),AddPage(familyId:widget.familyId,user:widget.user,onSaved:()=>setState(()=>tab=1)),StatsPage(familyId:widget.familyId),FamilyPage(familyId:widget.familyId)]; return Scaffold(body:SafeArea(child:pages[tab]),bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:const[NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Home'),NavigationDestination(icon:Icon(Icons.receipt_long_outlined),selectedIcon:Icon(Icons.receipt_long),label:'Movimenti'),NavigationDestination(icon:Icon(Icons.add_circle_outline),selectedIcon:Icon(Icons.add_circle),label:'Aggiungi'),NavigationDestination(icon:Icon(Icons.bar_chart_outlined),selectedIcon:Icon(Icons.bar_chart),label:'Statistiche'),NavigationDestination(icon:Icon(Icons.family_restroom_outlined),selectedIcon:Icon(Icons.family_restroom),label:'Famiglia')]));}}

Stream<QuerySnapshot<Map<String,dynamic>>> txStream(String id)=>FirebaseFirestore.instance.collection('families').doc(id).collection('transactions').orderBy('date',descending:true).snapshots();
String eur(num n)=>NumberFormat.currency(locale:'it_IT',symbol:'€').format(n);

class HomePage extends StatelessWidget { const HomePage({super.key,required this.familyId,required this.onAdd}); final String familyId; final VoidCallback onAdd;
 @override Widget build(BuildContext context)=>StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:txStream(familyId),builder:(context,s){final docs=s.data?.docs??[]; double income=0,expenses=0; for(final d in docs){final a=(d['amount']??0).toDouble(); if(a>0)income+=a;else expenses+=a.abs();} return ListView(padding:const EdgeInsets.all(20),children:[const Text('👋 Family Life €',style:TextStyle(fontSize:27,fontWeight:FontWeight.bold)),Text(DateFormat('MMMM yyyy','it_IT').format(DateTime.now())),const SizedBox(height:16),Card(color:const Color(0xFF13A89E),child:Padding(padding:const EdgeInsets.all(22),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Disponibilità familiare',style:TextStyle(color:Colors.white70)),Text(eur(income-expenses),style:const TextStyle(fontSize:34,fontWeight:FontWeight.bold,color:Colors.white)),const SizedBox(height:12),Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text('↑ ${eur(income)}',style:const TextStyle(color:Colors.white)),Text('↓ ${eur(expenses)}',style:const TextStyle(color:Colors.white))])]))),const SizedBox(height:12),FilledButton.icon(onPressed:onAdd,icon:const Icon(Icons.add),label:const Text('Aggiungi spesa')),const SizedBox(height:16),const Text('Ultimi movimenti',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),if(!s.hasData)const Padding(padding:EdgeInsets.all(24),child:Center(child:CircularProgressIndicator())),...docs.take(5).map((d){final x=d.data();final a=(x['amount']??0).toDouble();return ListTile(leading:CircleAvatar(child:Icon(a<0?Icons.shopping_bag_outlined:Icons.savings)),title:Text(x['title']??''),subtitle:Text('${x['type']??''} · ${x['payer']??''}'),trailing:Text(eur(a),style:TextStyle(fontWeight:FontWeight.bold,color:a<0?Colors.red:Colors.green)));})]);});}

class MovementsPage extends StatelessWidget { const MovementsPage({super.key,required this.familyId}); final String familyId; @override Widget build(BuildContext context)=>StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:txStream(familyId),builder:(context,s)=>ListView(padding:const EdgeInsets.all(20),children:[const Text('Movimenti',style:TextStyle(fontSize:28,fontWeight:FontWeight.bold)),const SizedBox(height:12),...((s.data?.docs??[]).map((d){final x=d.data();final a=(x['amount']??0).toDouble();final ts=x['date'] as Timestamp?;return Card(child:ListTile(title:Text(x['title']??''),subtitle:Text('${ts==null?'':DateFormat('dd/MM/yyyy').format(ts.toDate())} · ${x['type']??''} · ${x['payer']??''}'),trailing:Text(eur(a),style:TextStyle(fontWeight:FontWeight.bold,color:a<0?Colors.red:Colors.green))));}))]));}

class AddPage extends StatefulWidget { const AddPage({super.key,required this.familyId,required this.user,required this.onSaved}); final String familyId; final User user; final VoidCallback onSaved; @override State<AddPage> createState()=>_AddPageState(); }
class _AddPageState extends State<AddPage>{
final amount=TextEditingController(),title=TextEditingController();
final merchant=TextEditingController(),receiptDate=TextEditingController();
String kind='Familiare',payer='Enzo';bool income=false,saving=false,analysing=false; XFile? receipt;
List<String> receiptItems=[];

Future<void> pickReceipt(ImageSource source) async { final f=await ImagePicker().pickImage(source:source,imageQuality:80); if(f!=null&&mounted)setState(()=>receipt=f); }
Future<void> analyseReceipt() async {
 if(receipt==null){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Prima allega uno scontrino')));return;}
 setState(()=>analysing=true);
 final parsed=await ReceiptOcrService.analyse(receipt!.path);
 if(!mounted)return;
 setState(()=>analysing=false);
 final result=await Navigator.of(context).push<Map<String,dynamic>>(MaterialPageRoute(builder:(_)=>ReceiptAnalysisPage(imagePath:receipt!.path, initialTotal:parsed.total.isNotEmpty?parsed.total:amount.text, initialMerchant:parsed.merchant.isNotEmpty?parsed.merchant:merchant.text, initialDate:parsed.date.isNotEmpty?parsed.date:receiptDate.text, initialItems:parsed.items, rawText:parsed.rawText)));
 if(result!=null){setState((){merchant.text=result['merchant']??''; receiptDate.text=result['date']??''; amount.text=result['total']??amount.text; receiptItems=List<String>.from(result['items']??[]); if(title.text.trim().isEmpty && merchant.text.trim().isNotEmpty) title.text=merchant.text.trim();});}
}

void receiptSheet(){showModalBottomSheet(context:context,builder:(c)=>SafeArea(child:Wrap(children:[ListTile(leading:const Icon(Icons.camera_alt),title:const Text('Scatta una foto'),onTap:(){Navigator.pop(c);pickReceipt(ImageSource.camera);}),ListTile(leading:const Icon(Icons.photo_library),title:const Text('Scegli dalla galleria'),onTap:(){Navigator.pop(c);pickReceipt(ImageSource.gallery);})])));}
Future<void> save()async{final v=double.tryParse(amount.text.replaceAll(',','.'));if(v==null||title.text.trim().isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Inserisci importo e descrizione')));return;}setState(()=>saving=true);await FirebaseFirestore.instance.collection('families').doc(widget.familyId).collection('transactions').add({'title':title.text.trim(),'amount':income?v:-v,'type':income?'Entrata':kind,'payer':payer,'category':income?'Entrate':kind,'createdBy':widget.user.uid,'date':Timestamp.now(),'createdAt':FieldValue.serverTimestamp()});if(mounted){widget.onSaved();}}@override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(20),children:[const Text('Aggiungi movimento',style:TextStyle(fontSize:28,fontWeight:FontWeight.bold)),const SizedBox(height:16),SegmentedButton<bool>(segments:const[ButtonSegment(value:false,label:Text('Spesa')),ButtonSegment(value:true,label:Text('Entrata'))],selected:{income},onSelectionChanged:(v)=>setState(()=>income=v.first)),const SizedBox(height:16),TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Importo',prefixText:'€ ',border:OutlineInputBorder())),const SizedBox(height:12),TextField(controller:title,decoration:const InputDecoration(labelText:'Nome / Descrizione',border:OutlineInputBorder())),const SizedBox(height:16),Wrap(spacing:8,children:['Familiare','Personale','Elia'].map((x)=>ChoiceChip(label:Text(x),selected:kind==x,onSelected:(_)=>setState(()=>kind=x))).toList()),const SizedBox(height:16),Wrap(spacing:8,children:['Enzo','Partner','Conto comune'].map((x)=>ChoiceChip(label:Text(x),selected:payer==x,onSelected:(_)=>setState(()=>payer=x))).toList()),const SizedBox(height:18),if(receipt!=null) Card(child:ListTile(leading:ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.file(File(receipt!.path),width:54,height:54,fit:BoxFit.cover)),title:const Text('Scontrino allegato'),subtitle:const Text('Pronto per il salvataggio'),trailing:IconButton(icon:const Icon(Icons.close),onPressed:()=>setState(()=>receipt=null)))),OutlinedButton.icon(onPressed:receiptSheet,icon:const Icon(Icons.camera_alt_outlined),label:Text(receipt==null?'Allega scontrino':'Cambia scontrino')),
if(receipt!=null) ...[const SizedBox(height:8),FilledButton.tonalIcon(onPressed:analysing?null:analyseReceipt,icon:analysing?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.auto_awesome),label:Text(analysing?'Analisi in corso...':'Analizza scontrino'))],
if(merchant.text.trim().isNotEmpty) Padding(padding:const EdgeInsets.only(top:8),child:Card(child:ListTile(leading:const Icon(Icons.receipt_long),title:Text(merchant.text),subtitle:Text('Data: ${receiptDate.text.isEmpty?'non rilevata':receiptDate.text}${receiptItems.isEmpty?'':' · ${receiptItems.length} prodotti'}'))),
const SizedBox(height:14),FilledButton(onPressed:saving?null:save,style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(54)),child:saving?const CircularProgressIndicator():const Text('Salva su Family Life €'))]);}

class StatsPage extends StatelessWidget { const StatsPage({super.key,required this.familyId}); final String familyId; @override Widget build(BuildContext context)=>StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:txStream(familyId),builder:(context,s){final docs=s.data?.docs??[];final Map<String,double> by={};for(final d in docs){final x=d.data();final a=(x['amount']??0).toDouble();if(a<0){final c=(x['category']??'Altro').toString();by[c]=(by[c]??0)+a.abs();}}return ListView(padding:const EdgeInsets.all(20),children:[const Text('Statistiche',style:TextStyle(fontSize:28,fontWeight:FontWeight.bold)),const SizedBox(height:16),...by.entries.map((e)=>Card(child:ListTile(title:Text(e.key),trailing:Text(eur(e.value),style:const TextStyle(fontWeight:FontWeight.bold)))))]);});}

class FamilyPage extends StatelessWidget { const FamilyPage({super.key,required this.familyId}); final String familyId; @override Widget build(BuildContext context)=>FutureBuilder<DocumentSnapshot<Map<String,dynamic>>>(future:FirebaseFirestore.instance.collection('families').doc(familyId).get(),builder:(context,s){final d=s.data?.data();return ListView(padding:const EdgeInsets.all(20),children:[const Text('La nostra famiglia',style:TextStyle(fontSize:28,fontWeight:FontWeight.bold)),const SizedBox(height:16),Card(child:ListTile(title:Text(d?['name']??'Famiglia':'Caricamento...'),subtitle:Text('Codice invito: ${d?['inviteCode']??''}'))),const SizedBox(height:12),const Text('Condividi questo codice con il partner per entrare nella stessa famiglia.'),const SizedBox(height:24),OutlinedButton.icon(onPressed:()=>FirebaseAuth.instance.signOut(),icon:const Icon(Icons.logout),label:const Text('Esci'))]);});}




class ReceiptOcrResult {
  ReceiptOcrResult({required this.merchant,required this.date,required this.total,required this.items,required this.rawText});
  final String merchant,date,total,rawText; final List<String> items;
}

class ReceiptOcrService {
  static Future<ReceiptOcrResult> analyse(String path) async {
    final recognizer=TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final text=await recognizer.processImage(InputImage.fromFilePath(path));
      final lines=text.blocks.expand((b)=>b.lines).map((l)=>l.text.trim()).where((l)=>l.isNotEmpty).toList();
      final raw=lines.join('\n');
      final merchant=lines.isEmpty?'':lines.first;
      final dateMatch=RegExp(r'\b([0-3]?\d[/-][01]?\d[/-](?:20)?\d{2})\b').firstMatch(raw);
      final date=dateMatch?.group(1) ?? '';
      final amounts=RegExp(r'(?<!\d)(\d{1,4}[,.]\d{2})(?!\d)').allMatches(raw).map((m)=>m.group(1)!).toList();
      String total='';
      final totalLine=lines.where((l)=>RegExp(r'(TOTALE|TOT\.|IMPORTO)',caseSensitive:false).hasMatch(l)).toList();
      if(totalLine.isNotEmpty){
        final m=RegExp(r'(\d{1,4}[,.]\d{2})').allMatches(totalLine.last).toList();
        if(m.isNotEmpty) total=m.last.group(1)!;
      }
      if(total.isEmpty && amounts.isNotEmpty) total=amounts.last;
      final itemLines=lines.where((l)=>RegExp(r'\d{1,4}[,.]\d{2}').hasMatch(l) && !RegExp(r'(TOTALE|IVA|RESTO|PAGAMENTO)',caseSensitive:false).hasMatch(l)).take(30).toList();
      return ReceiptOcrResult(merchant:merchant,date:date,total:total,items:itemLines,rawText:raw);
    } finally { recognizer.close(); }
  }
}

class ReceiptAnalysisPage extends StatefulWidget {
 const ReceiptAnalysisPage({super.key,required this.imagePath,required this.initialTotal,required this.initialMerchant,required this.initialDate,required this.initialItems,required this.rawText});
 final String imagePath,initialTotal,initialMerchant,initialDate,rawText; final List<String> initialItems;
 @override State<ReceiptAnalysisPage> createState()=>_ReceiptAnalysisPageState();
}
class _ReceiptAnalysisPageState extends State<ReceiptAnalysisPage>{
 late final TextEditingController merchant=TextEditingController(text:widget.initialMerchant);
 late final TextEditingController total=TextEditingController(text:widget.initialTotal);
 late final TextEditingController date=TextEditingController(text:widget.initialDate);
 final item=TextEditingController(); late final List<String> items=List<String>.from(widget.initialItems);
 @override void dispose(){merchant.dispose();total.dispose();date.dispose();item.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('🤖 Analizza scontrino')),body:ListView(padding:const EdgeInsets.all(20),children:[
  ClipRRect(borderRadius:BorderRadius.circular(18),child:Image.file(File(widget.imagePath),height:240,width:double.infinity,fit:BoxFit.cover)),
  const SizedBox(height:16),Card(child:Padding(padding:const EdgeInsets.all(14),child:Text(widget.rawText.isEmpty?'Nessun testo rilevato. Puoi inserire i dati manualmente.':'Testo letto automaticamente. Controlla i dati prima di salvare.'))),
  const SizedBox(height:12),TextField(controller:merchant,decoration:const InputDecoration(labelText:'🏪 Negozio',border:OutlineInputBorder())),const SizedBox(height:12),
  TextField(controller:date,decoration:const InputDecoration(labelText:'📅 Data (gg/mm/aaaa)',border:OutlineInputBorder())),const SizedBox(height:12),
  TextField(controller:total,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'💰 Totale',prefixText:'€ ',border:OutlineInputBorder())),
  const SizedBox(height:16),const Text('🛒 Prodotti / voci',style:TextStyle(fontWeight:FontWeight.bold,fontSize:18)),const SizedBox(height:8),
  Row(children:[Expanded(child:TextField(controller:item,decoration:const InputDecoration(hintText:'Es. Pannolini - 24,90 €',border:OutlineInputBorder()))),IconButton(icon:const Icon(Icons.add_circle),onPressed:(){if(item.text.trim().isNotEmpty)setState((){items.add(item.text.trim());item.clear();});})]),
  ...items.asMap().entries.map((e)=>ListTile(title:Text(e.value),trailing:IconButton(icon:const Icon(Icons.close),onPressed:()=>setState(()=>items.removeAt(e.key)))),
  const SizedBox(height:20),FilledButton.icon(onPressed:()=>Navigator.pop(context,{'merchant':merchant.text.trim(),'date':date.text.trim(),'total':total.text.trim(),'items':items}),icon:const Icon(Icons.check),label:const Text('Conferma dati'))
 ]));
}
