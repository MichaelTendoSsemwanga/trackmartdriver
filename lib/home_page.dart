import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:share/share.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';

import 'about.dart';
import 'chat.dart';
import 'contact.dart';
import 'settings.dart';
import 'support.dart';
import 'map.dart';

class HomePage extends StatelessWidget {
  final VoidCallback onSignedout;
  final String currentUserId;

  HomePage({this.onSignedout, this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      theme: new ThemeData(
        primaryColor: const Color(0xff004d40),
        primaryColorDark: const Color(0xff005B9A),
        accentColor: const Color(0xff005B9A),
      ),
      title: "Trackmart Driver",
      home: new TabbedGuy(
        onSignedout: this.onSignedout,
        currentUserId: this.currentUserId,
      ),
    );
  }
}

class TabbedGuy extends StatefulWidget {
  const TabbedGuy({this.onSignedout, this.currentUserId});

  final VoidCallback onSignedout;
  final String currentUserId;

  @override
  _TabbedGuyState createState() =>
      new _TabbedGuyState(currentUserId: this.currentUserId);
}

class _TabbedGuyState extends State<TabbedGuy>
    with SingleTickerProviderStateMixin {
  bool isLoading = false;
  double quantity = 1;
  DatabaseReference databaseReference;
  FirebaseDatabase database;
  Firestore firestore;

  // final formKey = new GlobalKey<FormState>();
  // final key = new GlobalKey<ScaffoldState>();
  final TextEditingController _filter = new TextEditingController();
  FocusNode myFocusNode;
  String _searchText = "";
  Icon _searchIcon = new Icon(Icons.search);
  Widget _appBarTitle = new Text('Trackmart Driver');
  List<HistoryItem> _history = <HistoryItem>[];
  List<HistoryItem> _filteredHistory = <HistoryItem>[];
  SharedPreferences prefs;
  final String currentUserId;
  bool _status = false;
  Geolocator geolocator = Geolocator();
  StreamSubscription<Position> positionStreamSubscription;
  String currentUserName;
  String currentUserPhoto;
  static double currentLat;
  static double currentLong;

  //TODO: Don't draw anything before all loading is done, all thens have completed
  bool _stillLoading = true;

  _TabbedGuyState({this.currentUserId});

  static TabController _tabController;

  @override
  void initState() {
    super.initState();
    _startup().then((value) {
      if (mounted)
        setState(() {
          _stillLoading = !value;
        });
    }).catchError((e) {
      print(e.toString());
      //sho(e.toString(), context);
      if (mounted)
        setState(() {
          _stillLoading = false;
        });
    });
  }

  _updateLocation(Position position) {
    if (mounted)
      setState(() {
        currentLat = position.latitude;
        currentLong = position.longitude;
      });
    databaseReference
        .child('Drivers')
        .child(currentUserId)
        .child('transit')
        .once()
        .then((d) {
      Map<String, dynamic> map = d.value?.cast<String, dynamic>();
      map?.forEach((key, values) {
        databaseReference
            .child('buyers')
            .child(values['userId'])
            .child('transit')
            .child(key)
            //.child('dlat')
            //.set(
              //position.latitude,
              //'dlong':position.longitude
            //)
        .update({'dlat':position.latitude,'dlong':position.longitude})
            .then((v) {
          /*databaseReference
              .child('buyers')
              .child(values['userId'])
              .child('transit')
              .child(key)
              .child('dlong')
              .set(
                position.longitude,
                //'dlong':position.longitude
              )
              .then((v) {
            //print('Updated in transit $key');
          });*/
          //print('Updated in transit $key');
        });
      });
    });
    databaseReference
        .child('Drivers')
        .child(currentUserId)
        .update({
          'lat': position.latitude,
          'long': position.longitude,
        })
        .then((v) {})
        .catchError((e) {
          print(e.toString());
        });
  }

  Future<bool> _startup() async {
    database = FirebaseDatabase.instance;
    database.setPersistenceEnabled(true);
    database.setPersistenceCacheSizeBytes(10000000);
    databaseReference = database.reference();
    firestore = Firestore.instance;
    prefs = await SharedPreferences.getInstance();
    currentUserName = prefs.getString('displayName');
    currentUserPhoto = prefs.getString('photoUrl');
    await getWorkStatus();

    _filter.addListener(() {
      if (_filter.text.isEmpty) {
        if (mounted)
          setState(() {
            _searchText = "";
            _filteredHistory = _history;
          });
      } else {
        if (mounted)
          setState(() {
            _searchText = _filter.text;
          });
      }
    });
    _getHistory();
    _tabController = TabController(vsync: this, length: 3, initialIndex: 1);
    myFocusNode = FocusNode();
    return true;
  }

  @override
  void dispose() {
    myFocusNode.dispose();
    _tabController.dispose();
    positionStreamSubscription?.cancel();
    super.dispose();
  }

  getWorkStatus() async {
    bool status = (await databaseReference
            .child('drivers')
            .child(currentUserId)
            .child('status')
            .once())
        .value;
    setState(() {
      _status = status ?? false;
    });
    registerLocation(_status);
    return _status;
  }

  registerLocation(bool value) async {
    if (value) {
      //geolocator = Geolocator();
      await geolocator
          .getCurrentPosition(desiredAccuracy: LocationAccuracy.best)
          .then((value) {
        Position position = value;
        print('Location');
        print(position == null
            ? 'Unknown'
            : position.latitude.toString() +
                ', ' +
                position.longitude.toString());
        _updateLocation(position);
        //var geolocator = Geolocator();
        var locationOptions = LocationOptions(
            accuracy: LocationAccuracy.high, distanceFilter: 10);
        positionStreamSubscription = geolocator
            .getPositionStream(locationOptions)
            .listen((Position position) {
          print(position == null
              ? 'Unknown'
              : position.latitude.toString() +
                  ', ' +
                  position.longitude.toString());
          _updateLocation(position);
        });
      });
    } else
      positionStreamSubscription?.cancel();
  }

  updateWork(bool value) async {
    await databaseReference
        .child('drivers')
        .child(currentUserId)
        .child('status')
        .set(value);
    registerLocation(value);
    //TODO:also firestore
  }

  Widget build(BuildContext context) {
    return _stillLoading
        ? SafeArea(
            child: Scaffold(
                body: Container(
            color: Colors.white,
            child: Center(
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
              Icon(
                Icons.local_shipping,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              Container(
                margin: EdgeInsets.only(bottom: 8),
                width: 200,
                child: LinearProgressIndicator(),
              ),
              Center(
                child: Text('Trackmart Driver',
                    style: TextStyle(
                        fontSize: 20, color: Theme.of(context).accentColor)),
              ),
              Padding(
                padding: EdgeInsets.all(8),
                child: Center(
                  child: Text('Drive • Deliver • Earn',
                      style: TextStyle(
                          fontSize: 17, color: Theme.of(context).accentColor)),
                ),
              ),
            ])),
          )))
        : Scaffold(
            drawer: Drawer(
              child: ListView(
                // Important: Remove any padding from the ListView.
                padding: EdgeInsets.zero,
                children: <Widget>[
                  DrawerHeader(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                            context,
                            new MaterialPageRoute(
                                builder: (context) => new SettingsPage(
                                      firestore: firestore,
                                    )));
                      },
                      child: Center(
                          child: Column(children: <Widget>[
                        Material(
                          child: currentUserPhoto != null
                              ? CachedNetworkImage(
                                  placeholder: (context, url) => Container(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Theme.of(context).accentColor),
                                    ),
                                    width: 80.0,
                                    height: 80.0,
                                    //padding: EdgeInsets.all(15.0),
                                  ),
                                  imageUrl: currentUserPhoto,
                                  width: 80.0,
                                  height: 80.0,
                                  fit: BoxFit.cover,
                                )
                              : Icon(
                                  Icons.account_circle,
                                  size: 80.0,
                                ),
                          borderRadius: BorderRadius.all(Radius.circular(40.0)),
                          clipBehavior: Clip.hardEdge,
                        ),
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(currentUserName ?? '',
                              style: TextStyle(
                                  fontSize: 17,
                                  color: Theme.of(context).accentColor)),
                        ),
                      ])),
                    ),
                    decoration: BoxDecoration(),
                  ),
                  SwitchListTile(
                      title: Text(
                        _status ? 'Available' : 'Not available',
                      ),
                      secondary:
                          Icon(_status ? Icons.work : Icons.not_interested),
                      value: _status, //TODO: fix this
                      onChanged: (value) {
                        updateWork(value).then((v) {
                          setState(() {
                            _status = value;
                          });
                        });
                      }),
                  ListTile(
                    title: Text('Help'),
                    trailing: new Icon(
                      Icons.help,
                      color: Theme.of(context).accentColor,
                    ),
                    onTap: () {
                      Navigator.push(
                          context,
                          new MaterialPageRoute(
                              builder: (context) => new SupportPage()));
                    },
                  ),
                  ListTile(
                    title: Text('Contact'),
                    trailing: new Icon(
                      Icons.phone,
                      color: Theme.of(context).accentColor,
                    ),
                    onTap: () {
                      Navigator.push(
                          context,
                          new MaterialPageRoute(
                              builder: (context) => new ContactPage()));
                      // Update the state of the app.
                      // ...
                    },
                  ),
                  ListTile(
                    title: Text('About Trackmart Driver'),
                    trailing: new Icon(
                      Icons.local_shipping,
                      color: Theme.of(context).accentColor,
                    ),
                    onTap: () {
                      Navigator.push(
                          context,
                          new MaterialPageRoute(
                              builder: (context) => new About()));
                    },
                  ),
                  ListTile(
                    title: Text('Invite'),
                    trailing: new Icon(
                      Icons.share,
                      color: Theme.of(context).accentColor,
                    ),
                    onTap: () {
                      Share.share(
                          'You can make money and get more customers deliverying Sand to buyers using Trackmart Driver Driver app. Download it at https://play.google.com/sandtrackdriverapp?uid=${currentUserId}');
                      print(
                          'You can make money and get more customers deliverying Sand to buyers using Trackmart Driver Driver app. Download it at https://play.google.com/sandtrackdriverapp?uid=${currentUserId}');
                    },
                  ),
                  ListTile(
                    title: Text('Log out'),
                    trailing: new Icon(
                      Icons.exit_to_app,
                      color: Theme.of(context).accentColor,
                    ),
                    onTap: () {
                      widget.onSignedout();
                    },
                  ),
                ],
              ),
            ),
            appBar: _buildBar(context),
            body: new InkWell(
              onTapDown: (t) {
                FocusScope.of(context).requestFocus(new FocusNode());
              },
              child: TabBarView(
                controller: _tabController,
                children: [
                  new Column(
                    //modified
                    children: <Widget>[
                      //new
                      new Flexible(
                        child: _buildContacts(), //new
                      ),
                      //new
                    ], //new
                  ),
                  Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: _buildHome()),
                  new Column(
                    //modified
                    children: <Widget>[
                      //new
                      new Flexible(
                        //new
                        child: _buildHistory(), //new
                      ), //new
                    ], //new
                  ),
                ],
              ),
            ),
          );
  }

  Widget _buildBar(BuildContext context) {
    return new AppBar(
      actions: <Widget>[
        IconButton(
          icon: _searchIcon,
          onPressed: _searchPressed,
        ),
        IconButton(
          icon: Icon(Icons.map),
          onPressed: () {
            Navigator.push(
                context,
                new MaterialPageRoute(
                    builder: (context) => new MapPage2(
                          driverId: widget.currentUserId,
                          dlat: _TabbedGuyState.currentLat,
                          dlong: _TabbedGuyState.currentLong,
                          selectOrder: confirmOrder,
                        )));
          },
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        tabs: [
          Tab(text: ('Chats')),
          Tab(text: ('Delivery')),
          Tab(text: ('Earnings')),
        ],
      ),
      title: _appBarTitle,
    );
  }

  confirmOrder(String orderKey) {}
  static showModal(text, sent_context) {
    showDialog(
        context: sent_context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return new AlertDialog(
            title: Text(text),
            content: LinearProgressIndicator(),
            contentPadding: EdgeInsets.all(10.0),
          );
        });
  }

  Widget _buildContacts() {
    return Stack(
      children: <Widget>[
        // List
        Container(
          child: StreamBuilder(
            stream: firestore.collection('buyers').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).accentColor),
                  ),
                );
              } else {
                return ListView.separated(
                  separatorBuilder: (context, index) => Divider(),
                  itemBuilder: (context, index) =>
                      buildItem(context, snapshot.data.documents[index]),
                  itemCount: snapshot.data.documents.length,
                );
              }
            },
          ),
        ),
        Positioned(
          child: isLoading
              ? Container(
                  child: Center(
                    child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).accentColor)),
                  ),
                  color: Colors.white.withOpacity(0.8),
                )
              : Container(),
        )
      ],
    );
  }

  Widget buildItem(BuildContext context, DocumentSnapshot document) {
    return document['displayName']
            .toLowerCase()
            .contains(_searchText.toLowerCase())
        ? Container(
            child: FlatButton(
              child: Row(
                children: <Widget>[
                  Material(
                    child: document['photoUrl'] != null
                        ? CachedNetworkImage(
                            placeholder: (context, url) => Container(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).accentColor),
                              ),
                              width: 50.0,
                              height: 50.0,
                              //padding: EdgeInsets.all(15.0),
                            ),
                            imageUrl: document['photoUrl'],
                            width: 50.0,
                            height: 50.0,
                            fit: BoxFit.cover,
                          )
                        : Icon(
                            Icons.account_circle,
                            size: 50.0,
                            //color: greyColor,
                          ),
                    borderRadius: BorderRadius.all(Radius.circular(25.0)),
                    clipBehavior: Clip.hardEdge,
                  ),
                  Flexible(
                    child: Container(
                      child: Column(
                        children: <Widget>[
                          Container(
                            child: Text(
                              '${document['displayName']}',
                              style: TextStyle(
                                  color: Theme.of(context).primaryColor),
                            ),
                            alignment: Alignment.centerLeft,
                            margin: EdgeInsets.fromLTRB(10.0, 0.0, 0.0, 5.0),
                          ),
                        ],
                      ),
                      margin: EdgeInsets.only(left: 5.0),
                    ),
                  ),
                ],
              ),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => Chat(
                              peerName: document['displayName'],
                              //store: firestore,
                              peerId: document.documentID,
                              peerAvatar: document['photoUrl'],
                            )));
              },
              padding: EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0)),
            ),
            margin: EdgeInsets.only(left: 5.0, right: 5.0),
          )
        : Container(
            width: 0,
            height: 0,
          );
  }

  _buildInTransit() {
    return StreamBuilder(
      stream: databaseReference
          .child('Drivers')
          .child(currentUserId)
          .child('transit')
          .onValue,
      //TODO: on value changes, chill streambuilder, listen and setstate on names.
      builder: (context, snap) {
        if (snap.hasData &&
            !snap.hasError &&
            snap.data.snapshot.value != null) {
//taking the data snapshot.
          //DataSnapshot snapshot = snap.data.snapshot;
          List<HistoryItem> items = [];
//it gives all the documents in this list.
          //List<Map<String,dynamic>> _list=;
//Now we're just checking if document is not null then add it to another list called "item".
//I faced this problem it works fine without null check until you remove a document and then your stream reads data including the removed one with a null value(if you have some better approach let me know).
          Map<String, dynamic> map =
              snap.data.snapshot.value.cast<String, dynamic>();
          map.forEach((key, values) {
            if (values != null) {
              items.add(Order(
                getHistory: _getHistory,
                key: key,
                type: Order.TRANSIT,
                userId: values['userId'],
                userName: values['userName'],
                driverId: values['driverId'],
                driverName: values['driverName'],
                driverPhone: values['driverPhone'],
                quantity: values['quantity'].toDouble(),
                payment: values['payment'],
                price: values['price'].toDouble(),
                unit: values['unit'],
                timestamp: values['timestamp'],
                destlat: values['destlat'],
                destlong: values['destlong'],
              ).toHistoryItem());
            }
          });
          return items.isNotEmpty
              ? Column(children: <Widget>[
                  InkWell(
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text('In transit', style: TextStyle(fontSize: 16)),
                            IconButton(
                                icon: Icon(transit
                                    ? Icons.arrow_drop_up
                                    : Icons.arrow_drop_down),
                                onPressed: () {
                                  if (mounted)
                                    setState(() {
                                      transit = !transit;
                                    });
                                })
                          ]),
                      onTap: () {
                        if (mounted)
                          setState(() {
                            transit = !transit;
                          });
                      }),
                  transit
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: items,
                        )
                      : Container(width: 0, height: 0),
                ])
              : Container(width: 0, height: 0);
        } else {
          return Container(width: 0, height: 0);
        }
      },
    );
  }

  bool requested = true;
  bool transit = true;

  Widget _buildHome() {
    return SingleChildScrollView(
        child: Column(children: <Widget>[
      _buildInTransit(),
      StreamBuilder(
        stream: databaseReference
            .child('Drivers')
            .child(currentUserId)
            .child('requests')
            .orderByChild('timestamp')
            .onValue,
        //TODO: on value changes, chill streambuilder, listen and setstate on names.
        builder: (context, snap) {
          if (snap.hasData &&
              !snap.hasError &&
              snap.data.snapshot.value != null) {
//taking the data snapshot.
            //DataSnapshot snapshot = snap.data.snapshot;
            List<HistoryItem> items = [];
//it gives all the documents in this list.
            //List<Map<String,dynamic>> _list=;
//Now we're just checking if document is not null then add it to another list called "item".
//I faced this problem it works fine without null check until you remove a document and then your stream reads data including the removed one with a null value(if you have some better approach let me know).
            Map<String, dynamic> map =
                snap.data.snapshot.value.cast<String, dynamic>();
            map.forEach((key, values) {
              if (values != null) {
                items.add(Order(
                  type: Order.REQUESTED,
                  key: key,
                  userId: values['userId'],
                  userName: values['userName'],
                  driverId: values['driverId'],
                  driverName: values['driverName'],
                  driverPhone: values['driverPhone'],
                  quantity: values['quantity'].toDouble(),
                  payment: values['payment'],
                  price: values['price'].toDouble(),
                  unit: values['unit'],
                  timestamp: values['timestamp'],
                  destlat: values['destlat'],
                  destlong: values['destlong'],
                ).toHistoryItem());
              }
            });
            return items.isNotEmpty
                ? Column(children: <Widget>[
                    InkWell(
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Text('Requested', style: TextStyle(fontSize: 16)),
                              IconButton(
                                  icon: Icon(requested
                                      ? Icons.arrow_drop_up
                                      : Icons.arrow_drop_down),
                                  onPressed: () {
                                    if (mounted)
                                      setState(() {
                                        requested = !requested;
                                      });
                                  })
                            ]),
                        onTap: () {
                          if (mounted)
                            setState(() {
                              requested = !requested;
                            });
                        }),
                    requested
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: items,
                          )
                        : Container(width: 0, height: 0),
                    //Divider(),
                  ])
                : Container(width: 0, height: 0);
          } else {
            return Padding(
                padding: EdgeInsets.all(16),
                child: Text('No requested deliveries'));
          }
        },
      ),
    ]));
  }

  Widget _buildHistory() {
    if (_searchText.isNotEmpty) {
      List<HistoryItem> tempList = new List<HistoryItem>();
      for (int i = 0; i < _history.length; i++) {
        if (_history[i]
                .user
                .toLowerCase()
                .contains(_searchText.toLowerCase()) ||
            _history[i]
                .date
                .toLowerCase()
                .contains(_searchText.toLowerCase())) {
          tempList.add(_history[i]);
        }
      }
      _filteredHistory = tempList;
    }
    return SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      Container(
        height: 10,
      ),
      SingleChildScrollView(
          child: Column(children: <Widget>[
        _filteredHistory.length > 0
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: _filteredHistory,
              )
            : Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'No delivered orders to display',
                  textAlign: TextAlign.center,
                ))
      ]))
    ]));
  }

  void _searchPressed() {
    if (mounted)
      setState(() {
        if (this._searchIcon.icon == Icons.search) {
          if (_tabController.index == 1) _tabController.animateTo(0);
          this._searchIcon = new Icon(Icons.close);
          this._appBarTitle = new TextField(
            focusNode: myFocusNode,
            controller: _filter,
            decoration: new InputDecoration(
                //prefixIcon: new Icon(Icons.search),
                hintText:
                    'Search ${_tabController.index == 0 ? 'chats' : _tabController.index == 2 ? 'orders' : '...'}'),
          );
        } else {
          this._searchIcon = new Icon(Icons.search);
          this._appBarTitle = new Text('Trackmart');
          //filteredDrivers = names;
          _filteredHistory = _history;
          _filter.clear();
        }
      });
  }

  void _getHistory() async {
    Future<List<HistoryItem>> transactions() async {
      final Future<Database> database = openDatabase(
        path.join(await getDatabasesPath(), 'history.db'),
        onCreate: (db, version) {
          return db.execute(
              "CREATE TABLE history(timestamp DATETIME DEFAULT CURRENT_TIMESTAMP PRIMARY KEY, user TEXT, amount INTEGER, userId TEXT, quantity TEXT, payment TEXT, date TEXT, unit TEXT)");
        },
        version: 1,
      );
      final Database db = await database;
      final List<Map<String, dynamic>> maps =
          await db.query('history', orderBy: 'timestamp DESC');
      return List.generate(maps.length, (i) {
        return HistoryItem(
          type: Order.DELIVERED,
          userId: maps[i]['userId'],
          user: maps[i]['user'],
          quantity: double.parse(maps[i]['quantity']),
          payment: maps[i]['payment'],
          unit: maps[i]['unit'],
          date: maps[i]['date'],
          amount: maps[i]['amount'].toString(),
        );
      });
    }

    List<HistoryItem> tempList = await transactions();
    if (mounted)
      setState(() {
        _history = tempList;
        _filteredHistory = _history;
      });
  }
}

class HistoryItem extends StatefulWidget {
  HistoryItem(
      {this.getHistory,
      this.type,
      this.user,
      this.orderKey,
      this.userId,
      this.userPhone,
      this.quantity,
      this.payment,
      this.amount,
      this.unit,
      this.date,
      this.destlat,
      this.destlong,
      this.driverId});

  final int type;
  final String user;
  final double destlat;
  final double destlong;
  final String userId;
  final String driverId;
  final String userPhone;
  final String amount;
  final String payment;
  final double quantity;
  final String unit;
  final String date;
  final String orderKey;
  final VoidCallback getHistory;
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'userId': userId,
      'user': user,
      'quantity': quantity,
      'payment': payment,
      'date': date,
      'unit': unit,
      'amount': int.parse(amount)
    };
  }

  Future<void> insertHistory() async {
    final Future<Database> database = openDatabase(
      path.join(await getDatabasesPath(), 'history.db'),
      onCreate: (db, version) {
        return db.execute(
            "CREATE TABLE history(timestamp DATETIME DEFAULT CURRENT_TIMESTAMP PRIMARY KEY, user TEXT, amount INTEGER, userId TEXT, quantity TEXT, payment TEXT, date TEXT, unit TEXT)");
      },
      version: 1,
    );
    final Database db = await database;
    await db.insert(
      'history',
      toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    getHistory();
    //_TabbedGuy.
  }

  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return HistoryItemState();
  }
}

class HistoryItemState extends State<HistoryItem> {
  int distance;
  String avatar;
  HistoryItemState();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    Firestore.instance
        .collection('buyers')
        .document(widget.userId)
        .get()
        .then((d) {
      if (mounted)
        setState(() {
          avatar = d['photoUrl'];
        });
    });
    if (widget.type != Order.DELIVERED)
      Geolocator()
          .getPositionStream(LocationOptions(accuracy: LocationAccuracy.high, distanceFilter: 10))
          .listen((Position position) {
        Geolocator()
            .distanceBetween(position.latitude, position.longitude,
                widget.destlat, widget.destlong)
            .then((value) {
          if (mounted)
            setState(() {
              distance = value.toInt();
            });
        });
      });
  }

  info(name, avatar, distance, phone, driverId) {
    showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            child: SizedBox(
              height: 150,
              child: User(
                destlong: widget.destlong,
                destlat: widget.destlat,
                name: name,
                avatar: avatar,
                distance: distance,
                phone: phone,
                id: widget.userId,
                selected: true,
              ),
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return widget.type == Order.DELIVERED
        ? Column(
            children: <Widget>[
              Container(
                margin: EdgeInsets.only(left: 8, right: 8),
                child: InkWell(
                  onTap: () {
                    print('hi');
                    info(
                        widget.user,
                        avatar,
                        '${distance != null ? ((distance) / 1000).toStringAsFixed(2) + ' km' : ''}',
                        widget.userPhone,
                        widget.userId);
                  },
                  child: new Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      new Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () {
                            info(
                                widget.user,
                                avatar,
                                '${distance != null ? ((distance) / 1000).toStringAsFixed(2) + ' km' : ''}',
                                widget.userPhone,
                                widget.userId);
                          },
                          child: Material(
                            child: avatar != null
                                ? CachedNetworkImage(
                                    placeholder: (context, url) => Container(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.0,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Theme.of(context).accentColor),
                                      ),
                                      width: 50.0,
                                      height: 50.0,
                                      //padding: EdgeInsets.all(15.0),
                                    ),
                                    imageUrl: avatar,
                                    width: 50.0,
                                    height: 50.0,
                                    fit: BoxFit.cover,
                                  )
                                : new CircleAvatar(
                                    child: widget.user == null
                                        ? Icon(
                                            Icons.account_circle,
                                            size: 50.0,
                                            //color: greyColor,
                                          )
                                        : new Text(widget.user[0],
                                            style: TextStyle(fontSize: 30)),
                                    radius: 25),
                            borderRadius:
                                BorderRadius.all(Radius.circular(25.0)),
                            clipBehavior: Clip.hardEdge,
                          ),
                        ),
                      ),
                      Expanded(
                        child: new Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            new Text(widget.user?.split(' ')[0] ?? 'Buyer',
                                style: Theme.of(context).textTheme.subhead),
                            new Container(
                              margin: const EdgeInsets.only(top: 5.0),
                              child: new Text(widget.quantity == null
                                  ? ''
                                  : '${widget.quantity} ${widget.unit}${widget.quantity > 1 ? 's' : ''}'),
                            ),
                          ],
                        ),
                      ),
                      new Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          new Container(
                            margin: const EdgeInsets.only(bottom: 5.0),
                            child: new Text(widget.amount ?? ''),
                          ),
                          new Text(widget.date ?? ''),
                        ],
                      ),
                      /*IconButton(
                        icon: Icon(
                          Icons.info,
                          color: Theme.of(context).accentColor,
                        ),
                        onPressed: null),*/
                    ],
                  ),
                ),
              ),
              Divider()
            ],
          )
        : Card(
            child: Padding(
              padding: EdgeInsets.only(top: 8, left: 8, right: 8),
              child: Column(
                children: <Widget>[
                  new InkWell(
                    onTap: () {
                      info(
                          widget.user,
                          avatar,
                          '${distance != null ? ((distance) / 1000).toStringAsFixed(2) + ' km' : ''}',
                          widget.userPhone,
                          widget.userId);
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        new Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () {
                              info(
                                  widget.user,
                                  avatar,
                                  '${distance != null ? ((distance) / 1000).toStringAsFixed(2) + ' km' : ''}',
                                  widget.userPhone,
                                  widget.userId);
                            },
                            child: Material(
                              child: avatar != null
                                  ? CachedNetworkImage(
                                      placeholder: (context, url) => Container(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.0,
                                          valueColor: AlwaysStoppedAnimation<
                                                  Color>(
                                              Theme.of(context).accentColor),
                                        ),
                                        width: 50.0,
                                        height: 50.0,
                                        //padding: EdgeInsets.all(15.0),
                                      ),
                                      imageUrl: avatar,
                                      width: 50.0,
                                      height: 50.0,
                                      fit: BoxFit.cover,
                                    )
                                  : new CircleAvatar(
                                      child: widget.user == null
                                          ? Icon(
                                              Icons.account_circle,
                                              size: 50.0,
                                              //color: greyColor,
                                            )
                                          : new Text(widget.user[0],
                                              style: TextStyle(fontSize: 30)),
                                      radius: 25),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(25.0)),
                              clipBehavior: Clip.hardEdge,
                            ),
                          ),
                        ),
                        /*new Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () {
                            info(
                                widget.driver,
                                avatar,
                                '${distance != null ? ((distance) / 1000).toStringAsFixed(2) : '_'} km',
                                widget.driverPhone,
                                widget.driverId);
                          },
                          child: new CircleAvatar(
                            child: Text(widget.driver[0]),
                          ),
                        ),
                      ),*/
                        Expanded(
                          child: new Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              new Text(
                                  '${widget.user?.split(' ')[0] ?? ''} (${distance != null ? ((distance) / 1000).toStringAsFixed(2) + ' km' : ''})',
                                  style: Theme.of(context).textTheme.subhead),
                              new Container(
                                margin: const EdgeInsets.only(top: 5.0),
                                child: new Text(widget.quantity == null
                                    ? ''
                                    : '${widget.quantity} ${widget.unit}${widget.quantity > 1 ? 's' : ''}'),
                              ),
                            ],
                          ),
                        ),
                        new Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Text(widget.date),
                            new Container(
                              margin: const EdgeInsets.only(top: 5.0),
                              child: new Text(widget.amount ?? ''),
                            ),
                          ],
                        ),
                        //Text(date),
                      ],
                    ),
                  ),
                  new Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      /*FlatButton.icon(
                          label: Text('Info'),
                          icon: Icon(
                            Icons.info,
                            color: Theme.of(context).accentColor,
                          ),
                          onPressed: null),*/
                      FlatButton.icon(
                        label: Text('Cancel'),
                        icon: Icon(
                          Icons.cancel,
                          color: Theme.of(context).accentColor,
                        ),
                        onPressed: () => widget.type == Order.REQUESTED
                            ? _cancelOrder(widget.orderKey, context)
                            : _cancelTransitOrder(widget.orderKey,
                                context), /*_infoOn(orderKey,driverId)*/
                      ),
                      widget.type == Order.REQUESTED
                          ? FlatButton.icon(
                              label: Text('Confirm'),
                              icon: Icon(
                                Icons.check,
                                color: Theme.of(context).accentColor,
                              ),
                              onPressed: () => _confirmOrder(widget.orderKey,
                                  context), /*_infoOn(orderKey,driverId)*/
                            )
                          : widget.type == Order.TRANSIT
                              ? FlatButton.icon(
                                  label: Text('Drive'),
                                  icon: Icon(
                                    Icons.directions,
                                    color: Theme.of(context).accentColor,
                                  ),
                                  onPressed: () {
                                    print('destlat${widget.destlat}');
                                    Navigator.push(
                                        context,
                                        new MaterialPageRoute(
                                            builder: (context) => new MapPage(
                                                //driverId: widget.driverId,
                                                userName: widget.user,
                                                ulat: widget.destlat,
                                                ulong: widget.destlong,
                                                dlat:
                                                    _TabbedGuyState.currentLat,
                                                dlong: _TabbedGuyState
                                                    .currentLong)));
                                  }, /*_infoOn(orderKey,driverId)*/
                                )
                              /*: FlatButton.icon(
                                      label: Text('Complete'),
                                      icon: Icon(
                                        Icons.check_circle_outline,
                                        color: Theme.of(context).accentColor,
                                      ),
                                      onPressed: () {
                                        _finishOrder(widget.orderKey, context);
                                      }, */ /*_infoOn(orderKey,driverId)*/ /*
                                    )*/
                              : Container(width: 0, height: 0),
                      widget.type == Order.TRANSIT && (distance ?? 101) < 100
                          ? FlatButton.icon(
                              label: Text('Complete'),
                              icon: Icon(
                                Icons.check_circle_outline,
                                color: Theme.of(context).accentColor,
                              ),
                              onPressed: () {
                                _finishOrder(widget.orderKey, context);
                              }, /*_infoOn(orderKey,driverId)*/
                            )
                          : Container(width: 0, height: 0),
                    ],
                  ),
                ],
              ),
            ),
          );
    //Divider()
    /*],
    );*/
  }

  _cancelTransitOrder(String orderKey, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Confirm'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Cancel order\n$orderKey?'),
              Text('Buyer: ${widget.user}')
            ],
          ),
          actions: <Widget>[
            FlatButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.arrow_back),
              label: Text('Back'),
            ),
            //TODO:Replace all FlatButton with FlatButton.icon
            FlatButton.icon(
              onPressed: () {
                _deleteTransitOrder(orderKey, context).then((v) {
                  //Fluttertoast.showToast(msg: 'Delete successful');
                  Navigator.of(context).pop();
                });
              },
              icon: Icon(Icons.cancel),
              label: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  _cancelOrder(String orderKey, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Confirm'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Cancel order\n$orderKey?'),
              Text('Driver: ${widget.user}')
            ],
          ),
          actions: <Widget>[
            FlatButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.arrow_back),
              label: Text('Back'),
            ),
            //TODO:Replace all FlatButton with FlatButton.icon
            FlatButton.icon(
              onPressed: () {
                _deleteOrder(orderKey, context).then((v) {
                  //Fluttertoast.showToast(msg: 'Delete successful');
                  Navigator.of(context).pop();
                });
              },
              icon: Icon(Icons.cancel),
              label: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  _confirmOrder(String orderKey, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Confirm'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Cofirm order\n$orderKey\nand start delivery?'),
              Text('Buyer: ${widget.user}')
            ],
          ),
          actions: <Widget>[
            FlatButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.arrow_back),
              label: Text('Back'),
            ),
            //TODO:Replace all FlatButton with FlatButton.icon
            FlatButton.icon(
              onPressed: () {
                _TabbedGuyState.showModal('Confirming...', context);
                _startOrder(orderKey).then((v) {
                  //Fluttertoast.showToast(msg: 'Delete successful');
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                });
              },
              icon: Icon(Icons.check),
              label: Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  _startOrder(String orderKey) async {
    FirebaseDatabase database = new FirebaseDatabase();
    DatabaseReference dataRef = database.reference();
    var order = (await dataRef
            .child('Drivers')
            .child(widget.driverId)
            .child('requests')
            .child(orderKey)
            .once())
        .value;
    await dataRef
        .child('buyers')
        .child(widget.userId)
        .child('transit')
        .child(orderKey)
        .set(order);
    await dataRef
        .child('Drivers')
        .child(widget.driverId)
        .child('transit')
        .child(orderKey)
        .set(order);
    await dataRef
        .child('Drivers')
        .child(widget.driverId)
        .child('requests')
        .child(orderKey)
        .remove();
    await dataRef
        .child('buyers')
        .child(widget.userId)
        .child('requests')
        .child(orderKey)
        .remove();
  }

  _finishOrder(String orderKey, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Confirm'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Complete order\n$orderKey?'),
              Text('Driver: ${widget.user}'),
            ],
          ),
          actions: <Widget>[
            FlatButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.arrow_back),
              label: Text('Back'),
            ),
            //TODO:Replace all FlatButton with FlatButton.icon
            FlatButton.icon(
              onPressed: () async {
                _TabbedGuyState.showModal('Finishing...', context);
                await FirebaseDatabase.instance
                    .reference()
                    .child('Drivers')
                    .child(widget.driverId)
                    .child('transit')
                    .child(orderKey)
                    .remove()
                    .then((v) {
                  Navigator.of(context).pop();
                  widget.insertHistory().then((v) {
                    Navigator.of(context).pop();
                    _TabbedGuyState._tabController.animateTo(2);
                  });
                });
              },
              icon: Icon(Icons.check_circle_outline),
              label: Text('Complete'),
            ),
          ],
        );
      },
    );
  }

  _deleteTransitOrder(String orderKey, context) async {
    print('delete');
    _TabbedGuyState.showModal('Cancelling...', context);
    FirebaseDatabase database = new FirebaseDatabase();
    DatabaseReference dataRef = database.reference();
    await dataRef
        .child('Drivers')
        .child(widget.driverId)
        .child('transit')
        .child(orderKey)
        .remove();
    await dataRef
        .child('buyers')
        .child(widget.userId)
        .child('transit')
        .child(orderKey)
        .remove();
    Navigator.of(context).pop();
  }

  _deleteOrder(String orderKey, context) async {
    _TabbedGuyState.showModal('Cancelling...', context);
    FirebaseDatabase database = new FirebaseDatabase();
    DatabaseReference dataRef = database.reference();
    await dataRef
        .child('Drivers')
        .child(widget.driverId)
        .child('requests')
        .child(orderKey)
        .remove();
    await dataRef
        .child('buyers')
        .child(widget.userId)
        .child('requests')
        .child(orderKey)
        .remove();
    Navigator.of(context).pop();
  }
}

class Request extends StatelessWidget {
  final Order order;

  Request(this.order);

  @override
  Widget build(BuildContext context) {}
}

class User extends StatefulWidget {
  User(
      {this.distance,
      this.avatar,
      this.id,
      this.name,
      this.destlat,
      this.destlong,
      this.phone,
      this.selected = true});

  final String name;
  String avatar;
  final String phone;
  final String id;
  double destlat;
  double destlong;
  String distance;
  bool selected;

  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return UserState(distance: distance, avatar: avatar);
  }
}

class UserState extends State<User> {
  String distance;
  String avatar;

  UserState({this.distance, this.avatar});

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    Firestore.instance.collection('buyers').document(widget.id).get().then((d) {
      if (mounted)
        setState(() {
          avatar = d['photoUrl'];
        });
      widget.avatar = d['photoUrl'];
    });
    if(widget.destlat!=null)
    Geolocator()
        .distanceBetween(_TabbedGuyState.currentLat,
            _TabbedGuyState.currentLong, widget.destlat, widget.destlong)
        .then((value) {
      if (mounted)
        setState(() {
          distance = (value / 1000).toStringAsFixed(2) + ' km';
        });
    });
  }

  _launchURL() async {
    if (await canLaunch('tel:${widget.phone}')) {
      await launch('tel:${widget.phone}');
    } else {
      throw 'Could not launch tel:${widget.phone}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selected)
      return Card(
        shape: new RoundedRectangleBorder(
            side: new BorderSide(
                color: Theme.of(context).accentColor, width: 2.0),
            borderRadius: BorderRadius.circular(4.0)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ListTile(
              leading: Material(
                child: avatar != null
                    ? CachedNetworkImage(
                        placeholder: (context, url) => Container(
                          child: CircularProgressIndicator(
                            strokeWidth: 1.0,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).accentColor),
                          ),
                          width: 50.0,
                          height: 50.0,
                          //padding: EdgeInsets.all(15.0),
                        ),
                        imageUrl: avatar,
                        width: 50.0,
                        height: 50.0,
                        fit: BoxFit.cover,
                      )
                    : /* Icon(
              Icons.account_circle,
              size: 50.0,
              //color: greyColor,
            ),*/
                    new CircleAvatar(
                        child: widget.name == null
                            ? Icon(
                                Icons.account_circle,
                                size: 60.0,
                                //color: greyColor,
                              )
                            : new Text(widget.name[0],
                                style: TextStyle(fontSize: 30)),
                        radius: 30),
                borderRadius: BorderRadius.all(Radius.circular(25.0)),
                clipBehavior: Clip.hardEdge,
              ),
              title: Text(widget.name ?? ''),
              subtitle: Text(distance ?? ''),
              trailing: IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () {
                    if (mounted)
                      setState(() {
                        Navigator.of(context).pop();
                      });
                  }),
              selected: true,
            ),
            new Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                (widget.destlat!=null)?
                FlatButton.icon(
                    label: Text('Route'),
                    icon: Icon(
                      Icons.pin_drop,
                      color: Theme.of(context).accentColor,
                    ),
                    onPressed: () {
                      Navigator.push(
                          context,
                          new MaterialPageRoute(
                              builder: (context) => new MapPage(
                                    //driverId: widget.id,
                                    userName: widget.name,
                                    ulat: widget.destlat,
                                    ulong: widget.destlong,
                                    dlat: _TabbedGuyState.currentLat,
                                    dlong: _TabbedGuyState.currentLong,
                                  )));
                    }):Container(width: 0,height: 0,), //),
                widget.id!=null?FlatButton.icon(
                    label: Text('Text'),
                    icon: Icon(
                      Icons.textsms,
                      color: Theme.of(context).accentColor,
                    ),
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => Chat(
                                    peerName: widget.name,
                                    peerId: widget.id,
                                    peerAvatar: avatar,
                                  )));
                      /*_infoOn(orderKey,driverId)*/
                    }):Container(width: 0,height: 0,),
                widget.phone!=null?
                FlatButton.icon(
                    label: Text('Call'),
                    icon: Icon(
                      Icons.phone,
                      color: Theme.of(context).accentColor,
                    ),
                    onPressed: _launchURL):Container(width: 0,height: 0,),
                //),
              ],
            ),
          ],
        ),
      );
  }
}

class Order {
  final String userName;
  final String userId;
  final String driverName;
  final String driverPhone;
  final String userPhone;
  final String userAvatar;
  final String driverId;
  final double price;
  final String payment;
  final double quantity;
  final String unit;
  final String key;
  final VoidCallback getHistory;
  var timestamp;
  final double destlat;
  final double destlong;
  final int type;
  static final int REQUESTED = 1;
  static final int TRANSIT = 2;
  static final int DELIVERED = 3;

  Order(
      {this.getHistory,
      this.destlat,
      this.destlong,
      this.type,
      this.key,
      this.userId,
      this.userName,
      this.driverId,
      this.driverName,
      this.userAvatar,
      this.driverPhone,
      this.userPhone,
      this.quantity,
      this.payment,
      this.price,
      this.unit,
      this.timestamp});

  HistoryItem toHistoryItem() {
    return new HistoryItem(
        userPhone: userPhone,
        getHistory: getHistory,
        destlat: destlat,
        destlong: destlong,
        type: type,
        driverId: driverId,
        userId: userId,
        orderKey: key,
        user: userName,
        quantity: quantity,
        payment: payment,
        date: DateFormat('dd MMM kk:mm')
            .format(DateTime.fromMillisecondsSinceEpoch((timestamp))),
        amount: (price * quantity).toStringAsFixed(0),
        unit: unit);
  }

  Map<String, dynamic> toMap(String uid) {
    return {
      'userId': userId,
      'userName': userName,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'userPhone': userPhone,
      'userAvatar': userAvatar,
      'quantity': quantity,
      'payment': payment,
      'price': price,
      'unit': unit,
      'timestamp': timestamp,
      'userId': uid,
    };
  }
}
