
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Limitless'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  RTCPeerConnection _peerConnection;
  TextEditingController offerText=TextEditingController();
  TextEditingController messageController=TextEditingController();
  FilePickerResult _file;



  @override
  void initState() {
    _createPeerConnection().then((pc) {
      _peerConnection = pc;
    });
    super.initState();
  }


  void _addCandidate() async {
    String jsonString = offerText.text;
    dynamic session = await jsonDecode('$jsonString');
    print(session['candidate']);
    dynamic candidate =
    new RTCIceCandidate(session['candidate'], session['sdpMid'], session['sdpMlineIndex']);
    await _peerConnection.addCandidate(candidate);
  }
  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text("File Transfer test"),
        ),
        body: Column(
          children: [
            TextField(
              controller: offerText,
              decoration: InputDecoration(
                  labelText: 'SDP'
              ),
            ),
            TextField(
              controller: messageController,
              decoration: InputDecoration(
                  labelText: 'Message'
              ),
            ),
            RaisedButton(onPressed: createOfferSDP,
              child: Text("Offer"),
            ),
            RaisedButton(onPressed: createAnswerSDP,
              child: Text("Answer"),
            ),
            RaisedButton(onPressed: _setRemoteDescription,
              child: Text("set remote desc"),
            ),
            RaisedButton(onPressed: _addCandidate,
              child: Text("addCandidate"),
            ),
            RaisedButton(onPressed: _sendMessage,
              child: Text("Send Message"),
            ),
            RaisedButton(onPressed: _sendFile,
              child: Text("Send File"),
            ),
            RaisedButton(onPressed: _pickFile,
              child: Text("Pick File"),
            ),
          ],
        ),
      ),
    );
  }

  bool _offer=false;
  RTCDataChannel  DC;


  _createPeerConnection() async {
    Map<String, dynamic> configuration = {
      "iceServers": [
        {"url": "stun:stun.l.google.com:19302"},
      ]
    };

    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory": {
        "OfferToReceiveAudio": false,
        "OfferToReceiveVideo": false,
      },
      "optional": [{
        "RtpDataChannels": true
      }
      ],
    };

    RTCPeerConnection pc = await createPeerConnection(configuration, offerSdpConstraints);
    pc.onIceCandidate = (e) {
      if (e.candidate != null) {
        print(json.encode({
          'candidate': e.candidate.toString(),
          'sdpMid': e.sdpMid.toString(),
          'sdpMlineIndex': e.sdpMlineIndex,
        }));
      }
    };

    return pc;
  }

  createOfferSDP() async{
    _offer=true;
    RTCDataChannelInit dataChannelDict = RTCDataChannelInit();
    dataChannelDict.id = 1;
    dataChannelDict.ordered = true;
    dataChannelDict.protocol = "sctp";
    dataChannelDict.negotiated = false;
    if(_peerConnection!=null){
      DC = await _peerConnection.createDataChannel("label", dataChannelDict);
      DC.onDataChannelState=(RTCDataChannelState state){
        print("offer data channel state$state");

        DC.onMessage=(e){
          print("onMessage");
          if(!e.isBinary){
            print(e.text);

          }else{
            print(e.binary);
          }
        };
      };

      RTCSessionDescription offer= await _peerConnection.createOffer({});
      var session =parse(offer.sdp);
      _peerConnection.setLocalDescription(offer).then((value)async  =>{

        print(json.encode( session))
      }
      );
      setState(() {
        offerText.text=json.encode( session);
      });
    }
    else{
      print("RPC IS $_peerConnection");
    }

  }


  createAnswerSDP() async{

    RTCSessionDescription answer=await _peerConnection.createAnswer({});
    _peerConnection.setLocalDescription(answer);

    var session=parse(answer.sdp);
    setState(() {
      offerText.text=json.encode(session);
    });



    if(_peerConnection==null){
      print("_peerconnection is also null in answer");
    }
  }
  void _setRemoteDescription() async {

    if(!_offer){
      print("Answer Side");
      RTCDataChannelInit _dataChannelDict = RTCDataChannelInit();
      _dataChannelDict.id = 1;
      _dataChannelDict.ordered = true;
      _dataChannelDict.protocol = "sctp";
      _dataChannelDict.negotiated = false;
      if (_peerConnection != null) {
        DC = await _peerConnection.createDataChannel("label", _dataChannelDict);
        DC.onDataChannelState = (RTCDataChannelState state) {
          print("answer data channel state$state");
          DC.onMessage=(e){
            print("on message");
            if(!e.isBinary){
              print(e.text);

            }else{
              print(e.binary.length);
            }
          };
        };
      }
    }
    else{
      print("Offer Side");

    }
    String jsonString = offerText.text;
    dynamic session = await jsonDecode('$jsonString');

    String sdp = write(session, null);


    RTCSessionDescription description =
    new RTCSessionDescription(sdp, _offer ? 'answer' : 'offer');
    print(description.toMap());

    await _peerConnection.setRemoteDescription(description);


  }
  _pickFile() async {
    _file=await FilePicker.platform.pickFiles();
    print(_file.files.single.path);
  }
  _sendFile(){
    if(DC==null){
      print("DC IS NULl");
    }
    else{
      if(_file!=null){
        DC.send(RTCDataChannelMessage.fromBinary(_file.files.single.bytes));
      }else{
        print("File is null");
      }
    }

  }

  _sendMessage(){
    if(DC==null){
      print("DC IS NULl");
    }
    print(DC.state);
    try{
      DC.send(RTCDataChannelMessage(messageController.text));
    } catch(e){
      print(e);
    }
  }
}