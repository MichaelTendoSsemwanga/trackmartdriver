import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';
import 'package:latlong/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class MapPage extends StatefulWidget {
  MapPage({this.userName,this.ulat, this.ulong, this.dlat, this.dlong});
  double ulat;
  double dlat;
  double ulong;
  double dlong;
  String userName = 'Buyer';
  @override
  _MapState createState() => new _MapState(dlat:dlat,dlong:dlong);
}

class _MapState extends State<MapPage> {
  String distance;
  String duration;
  double dlat;
  double dlong;
  List<LatLng> points = [];
  LatLng _center;
  MapController _mapController = MapController();
  Geolocator geolocator = Geolocator();
  StreamSubscription<Position> positionStreamSubscription;
  var steps = [];
  String summary = 'Steps';
  String instruction;
  _MapState({this.dlong,this.dlat});
  @override
  void initState() {
_updateLocation(Position(longitude: dlong,latitude: dlat));
    /*points = <LatLng>[
      new LatLng(widget.lat, widget.long),
      new LatLng(widget.lat+0.001, widget.long),
      new LatLng(widget.lat, widget.long+0.001),
      new LatLng(widget.lat+0.0005, widget.long+0.0005),
      new LatLng(widget.lat, widget.long),
    ];*/
    var locationOptions = LocationOptions(
        accuracy: LocationAccuracy.high, distanceFilter: 10);
    positionStreamSubscription = geolocator
        .getPositionStream(locationOptions)
        .listen((Position position) {
      _updateLocation(position);
    });
    super.initState();
  }
  _updateLocation(Position position) {
    setState(() {
      dlat = position.latitude;
      dlong = position.longitude;
    });
    var url =
        'https://api.mapbox.com/directions/v5/mapbox/driving/${dlong},${dlat};${widget.ulong},${widget.ulat}?steps=true&access_token=pk.eyJ1IjoibWljaGFlbHRlbmRvIiwiYSI6ImNqeWQ0aXp4eTBvb3IzZW52MW1yNjE5a2EifQ.6z7-FOwn2hZuYFRvrIcsFQ';
    http.get(url).then((response) {
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      var route = json.decode(response.body)['routes'][0];
      print('route$route');
      steps = route['legs'][0]['steps'];
      summary = route['legs'][0]['summary'];
      var k =PolylinePoints().decodePolyline(route['geometry']);
      setState(() {
        points=List.generate(k.length, (i){
          return LatLng(k[i].latitude, k[i].longitude);
        });
        distance = '${(route['distance'] / 1000).toStringAsFixed(2)}km';
        duration = '${(route['duration'] / 60).toStringAsFixed(0)}min';
      });
    }).catchError((e){
      print(e.toString());
    });
  }
@override
void dispose(){
  positionStreamSubscription?.cancel();
  super.dispose();
}
  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text('Directions to ${widget.userName}'),
        actions: <Widget>[
          IconButton(
            icon: Icon(
              Icons.help,
              color: Colors.white,
            ),
            onPressed: instructions,
          )
        ],
      ),
      body:
          /*MapboxOverlay(
          controller: new MapboxOverlayController(),
          options: new MapboxMapOptions(
            style: Style.dark,
            camera: new CameraPosition(
                target: new LatLng(lat: widget.lat, lng: widget.long),
                zoom: 15.0,
                bearing: 0.0,
                tilt: 0.0),
          ),
        )*/
          Stack(
        children: <Widget>[
          FlutterMap(
            options: new MapOptions(
              onTap: (l) {
                print(l);
              },
              center: _center ?? new LatLng(widget.dlat, widget.dlong),
              zoom: 15.0,
            ),
            mapController: _mapController,
            layers: [
              new TileLayerOptions(
                urlTemplate: "https://api.tiles.mapbox.com/v4/"
                    "{id}/{z}/{x}/{y}@2x.png?access_token={accessToken}",
                additionalOptions: {
                  'accessToken':
                      'sk.eyJ1IjoibWljaGFlbHRlbmRvIiwiYSI6ImNqeWQ0bm50aDA3MjQzaW10cWY5NjQ2bjkifQ.D2FbpBl62dQgiNU9qHRdxw',
                  'id': 'mapbox.streets',
                },
              ),PolylineLayerOptions(polylines:[new Polyline(
    points: points,
    strokeWidth: 5.0,
    color: Theme.of(context).accentColor,
    )]),
              new MarkerLayerOptions(
                markers: [
                  new Marker(
                    width: 60.0,
                    height: 60.0,
                    point: new LatLng(dlat, dlong),
                    builder: (ctx) => new Container(
                      child: GestureDetector(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('You',
                                style:
                                    TextStyle(backgroundColor: Colors.white)),
                            /*IconButton(
                          icon: */
                            Icon(
                              Icons.local_shipping,
                              color: Theme.of(context).accentColor,
                              size: 30,
                            ), /*
                          onPressed: null),*/
                          ],
                        ),
                        onTap: () {
                          print('hi');
                        },
                      ),
                    ),
                  ),
                  new Marker(
                    width: 60.0,
                    height: 60.0,
                    point: new LatLng(widget.ulat, widget.ulong),
                    builder: (ctx) => new Container(
                      child: GestureDetector(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(widget.userName,maxLines: 1,
                                  style:
                                      TextStyle(backgroundColor: Colors.white)),
                              Icon(
                                Icons.person_pin_circle,
                                color: Theme.of(context).accentColor,
                                size: 30,
                              ),
                            ],
                          ),
                          onTap: () {
                            /*showDialog(
                                context: context,
                                builder: (context) {
                                  return Dialog(
                                    child: SizedBox(
                                      height: 150,
                                      child: User(
                                        destlong: destlong,
                                        destlat: destlat,
                                        name: name,
                                        avatar: avatar,
                                        distance: distance,
                                        phone: phone,
                                        id: userId,
                                        selected: true,
                                      ),
                                    ),
                                  );
                                });*/
                          }),
                    ),
                  ),
                ],
              ),
            ],
          ),
          distance != null
              ? Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        /*FlatButton.icon(
                          color: Colors.white,
                          onPressed: () {
                            instructions();
                          },
                          icon: Icon(
                            Icons.info,
                            color: Theme.of(context).accentColor,
                          ),
                          label: Text(instruction??'Steps'),
                        ),*/
                        /*Text(instruction,style:
                    TextStyle(backgroundColor: Colors.white)),*/
                        Text(steps[0]['maneuver']['instruction'],
                            style:
                            TextStyle(backgroundColor: Colors.white)),
                        FlatButton.icon(
                          color: Colors.white,
                          onPressed: () {
                            instructions();
                          },
                          icon: Icon(
                            Icons.directions,
                            color: Theme.of(context).accentColor,
                          ),
                          label: Text('${distance ?? ''} (${duration ?? ''})'),
                        ),
                      ],
                    ),
                  ),
                )
              : Align(
                  alignment: Alignment.bottomCenter,
    child: Padding(
    padding: EdgeInsets.only(bottom: 8),
    child: CircularProgressIndicator())),

          Align(alignment: Alignment.bottomLeft,
    child:Padding(
    padding: EdgeInsets.only(bottom: 8,right: 8),
    child: IconButton(iconSize:40,icon: Icon(Icons.my_location,color: Theme.of(context).accentColor),
                onPressed: (){
                  _mapController.move(LatLng(widget.dlat,
                      widget.dlong), _mapController.zoom);
                }),),
          ),
          Align(alignment: Alignment.bottomRight,
            child:Padding(
              padding: EdgeInsets.only(bottom: 8,right: 8),
              child: IconButton(iconSize:40,icon: Icon(Icons.person_pin_circle,color: Theme.of(context).accentColor),
                  onPressed: (){
                    _mapController.move(LatLng(widget.ulat,
                        widget.ulong), _mapController.zoom);
                  }),),
          ),
        ],
      ),
    );
  }

  void instructions() {
    showDialog(
        context: context,
        builder: (context) {
          return SimpleDialog(
            title: Text(summary),
            children: List.generate(steps.length, (i) {
              return ListTile(
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _mapController.move(
                        new LatLng(steps[i]['maneuver']['location'][1],
                            steps[i]['maneuver']['location'][0]),
                        _mapController.zoom);
                  });
                },
                title: Text(steps[i]['maneuver']['instruction']),
                subtitle: Text('${steps[i]['distance']} m'),
              );
            }),
          );
        });
  }
}

class MapPage2 extends StatefulWidget {
  MapPage2({@required this.driverId,this.selectOrder, this.dlat, this.dlong});
  final ValueChanged<String> selectOrder;
  final double dlat;
  final double dlong;
final String driverId;
  @override
  _MapState2 createState() => new _MapState2();
}

class _MapState2 extends State<MapPage2> {
  BuildContext context;
  List<String> names;
  List<String> distances;
  List<int> durations;
  List<LatLng> points=[];
  List<String> keys;
  LatLng _center;
  MapController _mapController = MapController();
  @override
  void initState() {
    print(widget.driverId);
    FirebaseDatabase.instance
        .reference()
        .child('Drivers')
    .child(widget.driverId)
    .child('requests')
        .onValue
        .listen((e) {
      Map<String, dynamic> map = e.snapshot.value?.cast<String, dynamic>();
      if (map != null) {
        names=[];
        distances=[];
        durations=[];
        points=[];
        keys=[];
        map.forEach((key, values) {
          var url =
              'https://api.mapbox.com/directions/v5/mapbox/driving/${values['destlong']},${values['destlat']};${widget.dlong},${widget.dlat}?access_token=pk.eyJ1IjoibWljaGFlbHRlbmRvIiwiYSI6ImNqeWQ0aXp4eTBvb3IzZW52MW1yNjE5a2EifQ.6z7-FOwn2hZuYFRvrIcsFQ';
          http.get(url).then((response) {
            print('Response status: ${response.statusCode}');
            print('Response body: ${response.body}');
            var route = json.decode(response.body)['routes'][0];
            if(mounted)setState(() {
              distances.add('${(route['distance'] / 1000).toStringAsFixed(2)}km');
              durations.add((route['duration'] / 60).toInt());
              if (values != null) {
                keys.add(key);
                names.add(values['displayName']);
                points.add(new LatLng(values['lat'], values['long']));
              }
              });
          });
        });
      }
      else showDialog(context: context,
      builder: (context){
        return AlertDialog(
          title: Text('No requests!'),
        );
      }
      );
    });
    //_updateLocation(Position(longitude: map['dlong'].toDouble(), latitude: map['dlat'].toDouble()));
    super.initState();
  }
  @override
  void dispose() {
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    this.context=context;
    return new Scaffold(
      appBar: new AppBar(
        title: new Text('Delivery requests'),
        actions: <Widget>[
          IconButton(
            icon: Icon(
              Icons.help,
              color: Colors.white,
            ),
            onPressed: () {}, //_eta//(){}//instructions,
          )
        ],
      ),
      body:
      /*MapboxOverlay(
          controller: new MapboxOverlayController(),
          options: new MapboxMapOptions(
            style: Style.dark,
            camera: new CameraPosition(
                target: new LatLng(lat: widget.lat, lng: widget.long),
                zoom: 15.0,
                bearing: 0.0,
                tilt: 0.0),
          ),
        )*/
      Stack(
        children: <Widget>[
          FlutterMap(
            options: new MapOptions(
              center: _center ?? new LatLng(widget.dlat, widget.dlong),
              zoom: 15.0,
            ),
            mapController: _mapController,
            layers: [
              new TileLayerOptions(
                urlTemplate: "https://api.tiles.mapbox.com/v4/"
                    "{id}/{z}/{x}/{y}@2x.png?access_token={accessToken}",
                additionalOptions: {
                  'accessToken':
                  'sk.eyJ1IjoibWljaGFlbHRlbmRvIiwiYSI6ImNqeWQ0bm50aDA3MjQzaW10cWY5NjQ2bjkifQ.D2FbpBl62dQgiNU9qHRdxw',
                  'id': 'mapbox.streets',
                },
              ),
              new MarkerLayerOptions(
                markers: [
                  Marker(
                    width: 60.0,
                    height: 60.0,
                    point: new LatLng(widget.dlat, widget.dlong),
                    builder: (ctx) => new Container(
                      child: GestureDetector(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('You',
                                  style: TextStyle(backgroundColor: Colors.white)),
                              Icon(
                                Icons.person_pin_circle,
                                color: Theme.of(context).accentColor,
                                size: 30,
                              ),
                            ],
                          ),
                          onTap: () {
                            print('hi');
                          }),
                    ),
                  ),
                ]+List.generate(points.length, (i){
                  return Marker(
                    width: 120,
                    height: 100,
                    point: points[i],
                    builder: (ctx) => new Container(
                      child: GestureDetector(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(names[i],
                                style: TextStyle(backgroundColor: Colors.white),maxLines: 1,),
                            Text('${distances[i]} (${durations[i]})',
                                style: TextStyle(backgroundColor: Colors.white)),
                            Icon(
                              Icons.local_shipping,
                              color: Theme.of(context).accentColor,
                              size: 30,
                            ),
                          ],
                        ),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: Text('ETA'),
                                content: Text(
                                  '${DateFormat('h:mm a').format(DateTime.now().add(Duration(minutes: durations[i])))}',
                                  style: TextStyle(
                                      color: Theme.of(context).accentColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 24),
                                ),
                                actions: <Widget>[
                                  FlatButton.icon(
                                      onPressed: () {
                                        widget.selectOrder(keys[i]);
                                        Navigator.of(context).pop();
                                        Navigator.of(this.context??context).pop();
                                      },
                                      icon: Icon(Icons.check),
                                      label: Text('Confirm'))
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          points.isNotEmpty
              ? Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  /*FlatButton.icon(
                          color: Colors.white,
                          onPressed: () {
                            instructions();
                          },
                          icon: Icon(
                            Icons.info,
                            color: Theme.of(context).accentColor,
                          ),
                          label: Text(instruction??'Steps'),
                        ),*/
                  /*Text(instruction,style:
                    TextStyle(backgroundColor: Colors.white)),*/ /*
                  Text(steps[0]['maneuver']['instruction'],
                            style: TextStyle(backgroundColor: Colors.white)),*/
                  FlatButton.icon(
                    color: Colors.white,
                    onPressed: list,
                    icon: Icon(
                      Icons.person_pin_circle,
                      color: Theme.of(context).accentColor,
                    ),
                    label: Text('Requests'),
                  ),
                ],
              ),
            ),
          )
              : Container(width: 0,height: 0,)/*Align(
    alignment: Alignment.bottomCenter,
    child: Padding(
    padding: EdgeInsets.only(bottom: 8),
    child: CircularProgressIndicator()))*/,
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: EdgeInsets.only(bottom: 8, right: 8),
              child: IconButton(
                  iconSize: 40,
                  icon: Icon(Icons.my_location,
                      color: Theme.of(context).accentColor),
                  onPressed: () {
                    _mapController.move(
                        LatLng(widget.dlat, widget.dlong), _mapController.zoom);
                  }),
            ),
          ),
          /*Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: EdgeInsets.only(bottom: 8, right: 8),
              child: IconButton(
                  iconSize: 40,
                  icon: Icon(Icons.local_shipping,
                      color: Theme.of(context).accentColor),
                  onPressed: () {
                    _mapController.move(
                        LatLng(dlat, dlong), _mapController.zoom);
                  }),
            ),
          ),*/
        ],
      ),
    );
  }
  void list() {
    showDialog(
        context: context,
        builder: (context) {
          return SimpleDialog(
            title: Text('Requests'),
            children: List.generate(points.length, (i) {
              return ListTile(
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _mapController.move(
                        points[i],
                        _mapController.zoom);
                  });
                },
                trailing:Text(distances[i]),
                title: Text(names[i]),
                subtitle: Text('${durations[i]} min'),
              );
            }),
          );
        });
  }

/*
  void _eta() {

  }
*/
}
