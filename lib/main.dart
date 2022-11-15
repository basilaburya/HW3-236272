import 'dart:io';
import 'dart:ui';
import 'package:flutter/src/material/floating_action_button.dart';
import 'package:provider/provider.dart';
import 'package:snapping_sheet/snapping_sheet.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';



import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:english_words/english_words.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

// ignore: constant_identifier_names
enum Status { UNINITIALIZED, AUTHENTICATED, AUTHENTICATING, UNAUTHENTICATED }

class AuthRepository with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;
  final FirebaseAuth _auth;
  User? _user;
  Status _status = Status.UNINITIALIZED;
  Set<WordPair> savedSet = {};

  AuthRepository.instance() : _auth = FirebaseAuth.instance {
    _auth.authStateChanges().listen(_onAuthStateChanged);
    _user = _auth.currentUser;
    _onAuthStateChanged(_user);
  }

  Status get status => _status;

  User? get user => _user;

  bool get isAuthenticated => status == Status.AUTHENTICATED;

  String get email => _user!.email!;

  Future<UserCredential?> signUp(String email, String password) async {
    try {
      _status = Status.AUTHENTICATING;
      notifyListeners();
      return await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
    } catch (e) {
      print(e);
      _status = Status.UNAUTHENTICATED;
      notifyListeners();
      return null;
    }
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _user = null;
      _status = Status.UNAUTHENTICATED;
    } else {
      _user = firebaseUser;
      _status = Status.AUTHENTICATED;
    }
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _status = Status.AUTHENTICATING;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      savedSet = await downloadSaved();
      notifyListeners();
      return true;
    } catch (e) {
      _status = Status.UNAUTHENTICATED;
      notifyListeners();
      return false;
    }
  }

  Future signOut() async {
    _auth.signOut();
    _status = Status.UNAUTHENTICATED;
    savedSet = {};
    notifyListeners();
    return Future.delayed(Duration.zero);
  }

  Future<String> getAvatarURL() async {
    try {
      return await _firebaseStorage
          .ref('Images')
          .child(user!.uid)
          .getDownloadURL();
    } catch (e) {
      return await _firebaseStorage
          .ref('Images')
          .child('Default')
          .getDownloadURL();
    }
  }

  Future<void> uploadAvatar(File img) async {
    await _firebaseStorage.ref("Images").child(user!.uid).putFile(img);
    notifyListeners();
  }

  Future<void> addPair(WordPair pair) async {
    if (isAuthenticated) {
      await _firestore
          .collection("Users")
          .doc(_user!.uid)
          .collection("Saved")
          .doc(pair.toString())
          .set({'first': pair.first, 'second': pair.second});
    }
    savedSet = await downloadSaved();
    notifyListeners();
  }



  Future<Set<WordPair>> downloadSaved() async {
    Set<WordPair> s = <WordPair>{};
    await _firestore
        .collection("Users")
        .doc(_user!.uid)
        .collection('Saved')
        .get()
        .then((querySnapshot) {
      for (var result in querySnapshot.docs) {
        final entriesCloud = result.data().entries;
        String first = entriesCloud.first.value.toString();
        String second = entriesCloud.last.value.toString();
        s.add(WordPair(first, second));
      }
    });
    return Future<Set<WordPair>>.value(s);
  }

  Future<void> removePair(WordPair pair) async {
    if (isAuthenticated) {
      await _firestore
          .collection("Users")
          .doc(_user!.uid)
          .collection('Saved')
          .doc(pair.toString())
          .delete();
      savedSet = await downloadSaved();
      //notifyListeners();
    }
    notifyListeners();
  }
}



class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool disableButton = false;
  var email = "-";
  var password = "-";
  late String confirmation;

  @override
  Widget build(BuildContext context) {
    AuthRepository.instance();
    final user = Provider.of<AuthRepository>(context);
    return Scaffold(
        appBar: AppBar(title: const Text('Login')),
        floatingActionButton: FloatingActionButton(
          onPressed:  () {
            print('Not implemented yet');
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Not implemented yet')));
          },
          tooltip: 'Increment',
          child: Icon(Icons.add),
          foregroundColor: Colors.white,
          backgroundColor: Colors.deepPurple,
        ),
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: Column(children: <Widget>[
              const Center(
                  child: Text(
                      'Welcome to Startup Names Generator, please log in below',
                      style: TextStyle(fontSize: 20))),

              const Padding(padding: EdgeInsets.all(13)),
              Center(
                  child: TextField(
                      decoration: const InputDecoration(labelText: 'Email'),
                      onChanged: (value) {
                        email = value;
                      },
                      keyboardType: TextInputType.emailAddress)),
              const Padding(padding: EdgeInsets.all(13)),
              Center(
                  child: TextField(
                      decoration: const InputDecoration(labelText: 'Password'),
                      onChanged: (value) {
                        password = value;
                      },
                      obscureText: true)),
              const Padding(padding: EdgeInsets.all(13)),
              Center(
                  child: disableButton
                      ? const CircularProgressIndicator()
                      : Column(children: <Widget>[
                    Container(
                      height: 40,
                      width: 320,
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(50)),
                      child: TextButton(
                          onPressed: () async {
                            setState(() {
                              disableButton = true;
                            });
                            final succeeded =
                            await user.signIn(email, password);
                            if (succeeded) {
                              Navigator.pop(context);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'There was an error logging into the app')));
                            }
                            setState(() {
                              disableButton = false;
                            });
                          },
                          child: Text('Log in',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondary,
                                  fontSize: 18))),
                    ),
                    const Padding(padding: EdgeInsets.all(7)),
                    Container(
                      height: 40,
                      width: 320,
                      decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(50)),
                      child: TextButton(
                          child: Text('New user? Click to sign up',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondary,
                                  fontSize: 18)),
                          onPressed: () async {
                            showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              builder: (BuildContext context) {
                                return AnimatedPadding(
                                    padding:
                                    MediaQuery.of(context).viewInsets,
                                    duration:
                                    const Duration(milliseconds: 100),
                                    curve: Curves.decelerate,
                                    child: Container(
                                        height: 200,
                                        color: Colors.white,
                                        child: Center(
                                            child: Column(
                                                mainAxisAlignment:
                                                MainAxisAlignment
                                                    .center,
                                                mainAxisSize:
                                                MainAxisSize.min,
                                                children: <Widget>[
                                                  const Text(
                                                      'Please confirm your password below:'),
                                                  const SizedBox(height: 20),
                                                  Padding(
                                                      padding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                          vertical: 0,
                                                          horizontal: 40),
                                                      child: Center(
                                                          child: TextField(
                                                              obscureText:
                                                              true,
                                                              decoration:
                                                              const InputDecoration(
                                                                  labelText:
                                                                  'Password'),
                                                              onChanged:
                                                                  (value) {
                                                                confirmation =
                                                                    value;
                                                              }))),
                                                  const SizedBox(height: 20),
                                                  Container(
                                                      height: 45,
                                                      width: 325,
                                                      decoration: BoxDecoration(
                                                          color: Colors.blue,
                                                          borderRadius:
                                                          BorderRadius
                                                              .circular(
                                                              50)),
                                                      child: TextButton(
                                                          onPressed:
                                                              () async {
                                                            setState(() {
                                                              disableButton =
                                                              true;
                                                            });
                                                            if (confirmation ==
                                                                password) {
                                                              if (await user.signUp(
                                                                  email,
                                                                  password) !=
                                                                  null) {
                                                                Navigator.pop(
                                                                    context);
                                                                Navigator.pop(
                                                                    context);
                                                              } else {
                                                                Navigator.pop(
                                                                    context);
                                                                ScaffoldMessenger.of(
                                                                    context)
                                                                    .showSnackBar(const SnackBar(
                                                                    content:
                                                                    Text('There was an error signing you up to the app')));
                                                              }
                                                            } else {
                                                              Navigator.pop(
                                                                  context);
                                                              ScaffoldMessenger.of(
                                                                  context)
                                                                  .showSnackBar(const SnackBar(
                                                                  content:
                                                                  Text('Passwords do not match')));
                                                            }
                                                            setState(() {
                                                              disableButton =
                                                              false;
                                                            });
                                                          },
                                                          child: Text(
                                                              'Confirm',
                                                              style: TextStyle(
                                                                  color: Theme.of(
                                                                      context)
                                                                      .colorScheme
                                                                      .secondary,
                                                                  fontSize:
                                                                  16))))
                                                ]))));
                              },
                            );
                          }),
                    ),
                  ]))
            ])));
  }
}


var blurx=0.0;
var blury=0.0;

void main() {
  blurx=0.0;
  blury=0.0;
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
        create: (_) => AuthRepository.instance(),
        child: MaterialApp(
            initialRoute: 'main_screen',
            routes: {
              'main_screen': (context) => const RandomWords(),
              'login_screen': (context) => const LoginScreen(),
            },
            theme: ThemeData(
                colorScheme: ColorScheme.fromSwatch(
                    primarySwatch: Colors.deepPurple,
                    accentColor: Colors.white)),
            title: 'Startup Name Generator',
            home: const RandomWords()));
  }
}

class RandomWords extends StatefulWidget {
  const RandomWords({Key? key}) : super(key: key);

  @override
  State<RandomWords> createState() => _RandomWordsState();

}

class _RandomWordsState extends State<RandomWords> {
  final _suggestions = <WordPair>[];
  final _savedLocal = <WordPair>{};
  final _biggerFont = const TextStyle(fontSize: 18);
  var user;
  bool minimized = false;
  SnappingSheetController snappingSheetController = SnappingSheetController();

  void _pushSaved() {

    Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) {
      if (user.isAuthenticated) {
        _savedLocal.addAll(user.savedSet);
      }
      final tiles = _savedLocal.map((pair) {
        return Dismissible(

            key: Key(pair.toString()),
            //ValueKey<int>(pair.hashCode),
            confirmDismiss: (DismissDirection direction) async {

              return await showDialog(

                  context: context,
                  builder: (BuildContext context) {
                    String name = pair.asPascalCase;

                    return AlertDialog(

                        title: const Text('Delete Suggestion'),
                        content: Text(
                            'Are you sure you want to delete $name from your saved suggestions?'),
                        actions: <Widget>[
                          ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Yes')),
                          ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('No'))
                        ]);
                  });
            },

            onDismissed: (DismissDirection direction) {
              setState(() {
                _savedLocal.remove(pair);
                user.removePair(pair);
              });
            },

            background: DefaultTextStyle(

                style:
                    TextStyle(color: Theme.of(context).colorScheme.secondary),
                child: Container(
                    color: Theme.of(context).colorScheme.primary,
                    child: Row(children: <Widget>[
                      Icon(Icons.delete,
                          color: Theme.of(context).colorScheme.secondary),
                      const Text('Delete Suggestion')
                    ]))),
            child:
                ListTile(title: Text(pair.asPascalCase, style: _biggerFont)));
      });
      final divided = tiles.isNotEmpty
          ? ListTile.divideTiles(context: context, tiles: tiles).toList()
          : <Widget>[];

      return Scaffold(
          appBar: AppBar(title: const Text('Saved Suggestions')),
          floatingActionButton: FloatingActionButton(
            onPressed:  () {
              print('Not implemented yet');
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Not implemented yet')));
            },
            tooltip: 'Increment',
            child: Icon(Icons.add),
            foregroundColor: Colors.white,
            backgroundColor: Colors.deepPurple,
          ),
          body: ListView(children: divided));
    }));
  }

  Widget _buildSuggestions() {
    /*
    return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: Container(
          color: Colors.transparent,
          child: ListView.builder(

              padding: const EdgeInsets.all(16),

              itemBuilder: (context, i) {

                if (i.isOdd) {
                  return const Divider();
                }
                final index = i ~/ 2;
                if (index >= _suggestions.length) {
                  _suggestions.addAll(generateWordPairs().take(10));
                }
                return _buildRow(_suggestions[index]);
              }),
        ));*/
    return Stack(
      children: <Widget>[
        ListView.builder(

            padding: const EdgeInsets.all(16),

            itemBuilder: (context, i) {

              if (i.isOdd) {
                return const Divider();
              }
              final index = i ~/ 2;
              if (index >= _suggestions.length) {
                _suggestions.addAll(generateWordPairs().take(10));
              }
              return _buildRow(_suggestions[index]);
            }), // Your child
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: blurx,
              sigmaY: blury,
            ),
            child: Center(
               // replace your loading widget
            ),
          ),
        )
      ],
    );
/*
    return ListView.builder(

        padding: const EdgeInsets.all(16),

        itemBuilder: (context, i) {

          if (i.isOdd) {
            return const Divider();
          }
          final index = i ~/ 2;
          if (index >= _suggestions.length) {
            _suggestions.addAll(generateWordPairs().take(10));
          }
          return _buildRow(_suggestions[index]);
        });*/
  }

  Widget _buildRow(WordPair pair) {
    final isSavedLocal = _savedLocal.contains(pair);
    final isSavedCloud = (user.isAuthenticated && user.savedSet.contains(pair));
    if (user.isAuthenticated && isSavedLocal && !isSavedCloud) {
      user.addPair(pair);
    }
    final isSavedAny = isSavedLocal || isSavedCloud;

    return ListTile(
        title: Text(pair.asPascalCase, style: _biggerFont),
        trailing: Icon(isSavedAny ? Icons.star : Icons.star_border,
            color: isSavedAny ? Theme.of(context).colorScheme.primary : null,
            semanticLabel: isSavedAny ? 'Remove from saved' : 'Save'),
        onTap: () {
          setState(() {
            if (isSavedAny) {
              _savedLocal.remove(pair);
              user.removePair(pair);
            } else {
              _savedLocal.add(pair);
              user.addPair(pair);
            }
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    user = Provider.of<AuthRepository>(context);

    return Scaffold(

        appBar: AppBar(title: const Text('Startup Name Generator'), actions: [

          IconButton(
              icon: const Icon(Icons.star),
              onPressed: _pushSaved,
              tooltip: 'Saved Suggestions'),
          IconButton(
              icon: user.isAuthenticated
                  ? const Icon(Icons.exit_to_app)
                  : const Icon(Icons.login),
              onPressed: user.isAuthenticated
                  ? () async {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Successfully logged out')));
                      await user.signOut();
                      _savedLocal.clear();
                    }
                  : () {
                      Navigator.pushNamed(context, 'login_screen');
                    },
              tooltip: user.isAuthenticated ? 'Logout' : 'Login')
        ]),
        body: GestureDetector(
            onTap: () => {
                  setState(() {
                    if (minimized) {
                      blurx=5.0;
                      blury=5.0;
                      ///If minimized make not minimized
                      snappingSheetController.snapToPosition(
                          const SnappingPosition.factor(
                              positionFactor: 0.200,
                              snappingCurve: Curves.easeInOut,
                              snappingDuration: Duration(milliseconds: 400)));
                    } else {
                      blurx=0.0;
                      blury=0.0;
                      snappingSheetController.snapToPosition(
                          const SnappingPosition.factor(
                              positionFactor: 0.07,
                              snappingCurve: Curves.easeInOut,
                              snappingDuration: Duration(milliseconds: 400)));
                    }
                    minimized = !minimized;
                  })
                },
            child: SnappingSheet(
                controller: snappingSheetController,
                lockOverflowDrag: true,
                child: _buildSuggestions(),
                snappingPositions: const [
                  SnappingPosition.factor(
                      positionFactor: 0.200,
                      snappingCurve: Curves.easeIn,
                      snappingDuration: Duration(milliseconds: 350)),
                  SnappingPosition.factor(
                      positionFactor: 0.8,
                      snappingCurve: Curves.easeInBack,
                      snappingDuration: Duration(milliseconds: 1)),
                ],
                sheetBelow: !user.isAuthenticated
                    ? null
                    : SnappingSheetContent(
                        draggable: !minimized,
                        child: Container(
                            color: Theme.of(context).colorScheme.secondary,
                            child: ListView(
                                physics: const NeverScrollableScrollPhysics(),
                                children: [
                                  Column(children: [
                                    Row(children: <Widget>[
                                      Expanded(
                                          child: Container(
                                              height: 50,
                                              color: Colors.grey[400],
                                              child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: <Widget>[
                                                    Flexible(
                                                        flex: 3,
                                                        child: Center(
                                                            child: Text(
                                                                "Welcome back, " +
                                                                    user.email,
                                                                style: const TextStyle(
                                                                    fontSize:
                                                                        16.0)))),
                                                    IconButton(
                                                        icon: minimized
                                                            ? const Icon(Icons
                                                                .keyboard_arrow_up)
                                                            : const Icon(Icons
                                                                .keyboard_arrow_down),
                                                        onPressed: null)
                                                  ])))
                                    ]),
                                    Row(children: <Widget>[
                                      FutureBuilder(
                                          future: user.getAvatarURL(),
                                          builder: (context,
                                              AsyncSnapshot<String> snapshot) {
                                            return Padding(
                                                padding:
                                                    const EdgeInsets.all(14),
                                                child: CircleAvatar(
                                                  radius: 30,
                                                  backgroundImage:
                                                      snapshot.data != null
                                                          ? NetworkImage(
                                                              snapshot.data!)
                                                          : null,
                                                ));
                                          }),
                                      Column(children: <Widget>[
                                        Text(user.email, style: _biggerFont),
                                        MaterialButton(
                                            onPressed: () async {
                                              FilePickerResult? result =
                                                  await FilePicker.platform
                                                      .pickFiles(
                                                          allowedExtensions: [
                                                    'png',
                                                    'jpg',
                                                    'gif',
                                                    'bmp',
                                                    'jpeg',
                                                    'webp'
                                                  ],
                                                          type:
                                                              FileType.custom);
                                              if (result != null) {
                                                File file = File(
                                                    result.files.single.path!);
                                                user.uploadAvatar(file);
                                              } else {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(const SnackBar(
                                                        content: Text(
                                                            'No image selected')));
                                              }
                                            },
                                            textColor: Theme.of(context)
                                                .colorScheme
                                                .secondary,
                                            //padding
                                            child: Container(
                                              decoration: const BoxDecoration(
                                                  color: Colors.blue),
                                              padding: const EdgeInsets.all(5),

                                              ///The box size
                                              child: const Text('Change Avatar',
                                                  style:
                                                      TextStyle(fontSize: 17)),
                                            ))
                                      ])
                                    ]),
                                  ])
                                ])))))); //));
  }
}

class App extends StatelessWidget {
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
              body: Center(
                  child: Text(snapshot.error.toString(),
                      textDirection: TextDirection.ltr)));
        }
        if (snapshot.connectionState == ConnectionState.done) {
          return const MyApp();
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}


