import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
//import 'map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'stopwatch.dart';
import 'forms.dart';
import 'dart:async';
import 'DistanceTracker.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart';

class distanceTraveled extends StatefulWidget {
  _distanceTraveled createState() => _distanceTraveled();
}

class _distanceTraveled extends State<distanceTraveled> {
  final _formkey = GlobalKey<FormState>();
  TrailData _data = TrailData();

  DistanceTracker _tracker = DistanceTracker();
  Stopwatch _stopwatch = Stopwatch();

  Duration timerInterval;
  Timer _timer;
  bool started = false;
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  CollectionReference database =
      FirebaseFirestore.instance.collection('trails');
  final FirebaseAuth auth = FirebaseAuth.instance;
  Marker marker;
  Uint8List imagePing;
  GoogleMapController mapController;

  StreamSubscription locationStream;
  Location currentLocation = Location();

  //works as constructor for class
  void start() async {
    timerInterval = Duration(seconds: 1);
    _timer = Timer.periodic(timerInterval, update);
    imagePing = await getMarkerImage();
  }

  void update(_) {
    setState(() {});
  }

  //get markerIcon.png from assets folder, convert it to Uint8 list return it
  Future<Uint8List> getMarkerImage() async {
    ByteData image =
        await DefaultAssetBundle.of(context).load("assets/markerIcon.png");
    return image.buffer.asUint8List();
  }

  void updateMarkerLocation() {
    Position pos = _tracker.GetCurrentLocation();
    if (pos != null) {
      LatLng curLatLng = LatLng(pos.latitude, pos.longitude);
      marker = Marker(
        markerId: MarkerId("root"),
        position: curLatLng,
        draggable: false,
        anchor: Offset(0.5, 0.5),
        icon: BitmapDescriptor.fromBytes(imagePing),
      );

      if (locationStream != null) locationStream.cancel();

      locationStream = currentLocation.onLocationChanged.listen((newLocalData) {
        if (mapController != null) {
          mapController.animateCamera(CameraUpdate.newCameraPosition(
              new CameraPosition(
                  bearing: 192.8,
                  target: LatLng(newLocalData.latitude, newLocalData.longitude),
                  zoom: 18.00)));
        }
      });
    }
  }

  Future<void> _endRide() async {
    return showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('End Ride'),
            content: Form(
                key: _formkey,
                child: Container(
                  height: 200,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text('Are you sure you want to end the ride?'),
                        buildTrailName(_data),
                        buildDifficulty(_data),
                        buildPaved(_data),
                      ],
                    ),
                  ),
                )),
            actions: <Widget>[
              FlatButton(
                  child: Text('CONTINUE'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  }),
              FlatButton(
                  child: Text('END'),
                  onPressed: () {
                    if (_formkey.currentState.validate()) {
                      _formkey.currentState.save();
                      setTime(_data, _stopwatch.GetHours(),
                          _stopwatch.GetMinutes(), _stopwatch.GetSeconds());
                      setDistance(_data, _tracker.PrintDistanceInMiles());
                      setUser(_data, auth);
                      print('Trail Name: ${_data.trailName}');
                      print('Difficulty: ${_data.difficulty}');
                      print(
                          'Time: ${_data.hours}:${_data.minutes}:${_data.seconds}');
                      print(
                          "Trail length: ${_data.totalDistance.toStringAsFixed(2)} Mi");
                      if (_data.pavement == true)
                        print('Trail is paved');
                      else
                        print('Trail is not paved');
                      _stopwatch.ResetStopwatch();
                      addTrail(_data, database);
                      _tracker.StopTrackingDistance();
                      Navigator.of(context).pop();
                    }
                  })
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    if (!started) {
      start();
      started = true;
    }
    updateMarkerLocation();
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text("Track Ride"),
        backgroundColor: Colors.red,
      ),
      backgroundColor: Colors.blueGrey,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                    target: LatLng(39.7285, -121.837479), zoom: 16.00),
                markers: Set.of((marker != null) ? [marker] : []),
                polylines: _tracker.GetPolylines(),
                onMapCreated: (GoogleMapController controller) {
                  mapController = controller;
                },
              ),
              width: 350,
              height: 400,
              padding: new EdgeInsets.only(bottom: 25),
            ),
            Text(
              _stopwatch.GetTime(),
              style: TextStyle(
                fontSize: 60.0,
              ),
            ),
            Text(
              _tracker.PrintDistanceInMiles().toStringAsFixed(2) + "  Mi",
              style: TextStyle(
                fontSize: 60.0,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RaisedButton(
                  padding:
                      EdgeInsets.symmetric(horizontal: 45.0, vertical: 8.0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  color: Colors.green,
                  child: Text(
                    'START',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  onPressed: () {
                    _tracker.StartTrackingDistance();
                    _stopwatch.StartStopwatch();
                  },
                ),
                SizedBox(width: 30.0),
                RaisedButton(
                  padding:
                      EdgeInsets.symmetric(horizontal: 45.0, vertical: 8.0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  color: Colors.red,
                  child: Text(
                    'END',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  onPressed: () {
                    _stopwatch.PauseStopwatch();
                    _tracker.PauseTrackingDistance();
                    _endRide();
                  },
                ),
              ], // RowChildren
            ),
            RaisedButton(
              padding: EdgeInsets.symmetric(horizontal: 45.0, vertical: 8.0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              color: Colors.white24,
              child: Text(
                'PAUSE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20.0,
                ),
              ),
              onPressed: () {
                _tracker.PauseTrackingDistance();
                _stopwatch.PauseStopwatch();
              },
            ),
          ], // ColumnChildren
        ),
      ),
    );
  } // Build
} // DistanceTraveled
