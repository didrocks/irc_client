library irc_client;

import 'package:unittest/unittest.dart';
import 'package:unittest/mock.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:logging/logging.dart';

part '../lib/src/constants.dart';
part '../lib/src/connection.dart';
part '../lib/src/command.dart';
part '../lib/src/handler.dart';
part '../lib/src/nickserv.dart';
part '../lib/src/client.dart';

main() {
  group('Command', () {
    test('should recognise prefix', () {
      var cmd = new Command(":prefix more stuff");
      expect(cmd.prefix, equals("prefix"));
    });
    
    test('should have empty prefix if missing', () {
      var cmd = new Command("just stuff");
      expect(cmd.prefix, equals(null));
    });
    
    test('should have empty prefix if empty command', () {
      var cmd = new Command("");
      expect(cmd.prefix, equals(null));
    });
    
    test('should have prefix if empty command with prefix', () {
      var cmd = new Command(":prefix");
      expect(cmd.prefix, equals("prefix"));
    });
    
    test('should have prefix if empty command with prefix and space', () {
      var cmd = new Command(":prefix ");
      expect(cmd.prefix, equals("prefix"));
    });
    
    test('should have empty prefix just space', () {
      var cmd = new Command(" ");
      expect(cmd.prefix, equals(null));
    });
    
    test('should have empty prefix just spaces', () {
      var cmd = new Command("     ");
      expect(cmd.prefix, equals(null));
    });
    
    test('should have prefix if empty command with prefix and spaces', () {
      var cmd = new Command(":prefix    ");
      expect(cmd.prefix, equals("prefix"));
    });
    
    test('should have command when prefixed', () {
      var cmd = new Command(":prefix command");
      expect(cmd.command, equals("command"));
    });
    
    test('should have command when not prefixed', () {
      var cmd = new Command("command");
      expect(cmd.command, equals("command"));
    });
    
    test('should have params', () {
      var cmd = new Command(":prefix command p1 p2 p3");
      expect(cmd.params.length, equals(3));
    });
    
    test('should have params', () {
      var cmd = new Command(":prefix command p1 p2 p3");
      expect(cmd.params[1], equals("p2"));
    });
    
    test('should have params when not prefixed', () {
      var cmd = new Command("command p1 p2 p3");
      expect(cmd.params[1], equals("p2"));
    });
    
    test('should have trailing stuff', () {
      var cmd = new Command("command p1 p2 p3 :this is trailing");
      expect(cmd.trailing, equals("this is trailing"));
    });
    
    test('should have trailing stuff with prefix', () {
      var cmd = new Command(":prefix command p1 p2 p3 :this is trailing");
      expect(cmd.trailing, equals("this is trailing"));
    });
    
    test('should have trailing stuff with prefix without colon', () {
      var cmd = new Command(":prefix command p1 p2 p3 trailing");
      expect(cmd.trailing, equals("trailing"));
    });
  });
  
  group('namesAreEqual', () {
    test('should think {==[', () {
      expect(namesAreEqual("{", "["), isTrue);
    });

    test('should think }==]', () {
      expect(namesAreEqual("}", "]"), isTrue);
    });

    test(r'should think |==\', () {
      expect(namesAreEqual("|", r"\"), isTrue);
    });

    test('should think ^==~', () {
      expect(namesAreEqual("^", "~"), isTrue);
    });

    test(r'should think JAMES[]\~==james{}|^', () {
      expect(namesAreEqual(r"JAMES[]\~", "james{}|^"), isTrue);
    });
  });
  
  group('isChannel', () {
    test('should recognise channel starting with #', () {
      expect(isChannel("#thing"), isTrue);
    });

    test('should recognise channel starting with &', () {
      expect(isChannel("&thing"), isTrue);
    });

    test('should recognise channel starting with +', () {
      expect(isChannel("+thing"), isTrue);
    });

    test('should recognise channel starting with !', () {
      expect(isChannel("!thing"), isTrue);
    });


    test('should not recognise non-channels', () {
      expect(isChannel("thing"), isFalse);
      expect(isChannel("thing+"), isFalse);
      expect(isChannel("thi#ng"), isFalse);
      expect(isChannel("th#ing"), isFalse);
      expect(isChannel("t###"), isFalse);
    });
  });
  
  group('Irc', () {
    var socket;
    var cnx;
    var sb;
    
    setUp(() {
      sb = new StringBuffer();
      socket = new MockSocket();
      socket.when(callsTo('writeln')).alwaysCall(sb.writeln);
      cnx = new Connection._(null, null, null, null, new List<Handler>());
      cnx._socket = socket;
    });
    
    test('should write', () {
      cnx.write("hello");
      expect(sb.toString(), equals("hello\n"));
    });

    test('should send message', () {
      cnx.sendMessage("person", "message");
      expect(sb.toString(), equals("PRIVMSG person :message\n"));
    });

    test('should send notice', () {
      cnx.sendNotice("person", "notice");
      expect(sb.toString(), equals("NOTICE person :notice\n"));
    });

    test('should join channel', () {
      cnx.join("#channel");
      expect(sb.toString(), equals("JOIN #channel\n"));
    });

    test('should set nick', () {
      expect(cnx.nick, isNull);
      cnx.setNick("bob");
      expect(sb.toString(), equals("NICK bob\n"));
      expect(cnx.nick, equals("bob"));
    });

    test('should split messages on last whitespace if > LIMIT_MESSAGE_SIZE', () {
      var command = "CMD person";
      var sbMessage1 = new StringBuffer(), sbMessage2 = new StringBuffer(), sbMessage3 = new StringBuffer();
      for (var i = 0; i < LIMIT_MESSAGE_SIZE-10; i++) {
        sbMessage1.write("a");
      }
      sbMessage2.write("bbbbb");
      for (var i = 0; i < 20; i++) {
        sbMessage3.write("c");
      }
      cnx.splitAndWrite(command, "${sbMessage1.toString()} ${sbMessage2.toString()} ${sbMessage3.toString()}");
      socket.getLogs(callsTo('writeln')).verify(happenedExactly(2));
      expect(socket.getLogs(callsTo('writeln')).logs[0].args, equals(["$command :${sbMessage1.toString()} ${sbMessage2.toString()}"]));
      expect(socket.getLogs(callsTo('writeln')).logs[1].args, equals(["$command :${sbMessage3.toString()}"]));
    });

    test('should split messages that are > LIMIT_MESSAGE_SIZE  without spaces in multiple requests', () {
      var command = "CMD person";
      var sbMessagePart1 = new StringBuffer(), sbMessagePart2 = new StringBuffer(), sbMessagePart3 = new StringBuffer();
      for (var i = 0; i < LIMIT_MESSAGE_SIZE; i++) {
        sbMessagePart1.write("a");
        sbMessagePart2.write("b");
        sbMessagePart3.write("c");
      }
      cnx.splitAndWrite(command, "${sbMessagePart1.toString()}${sbMessagePart2.toString()}${sbMessagePart3.toString()}");
      socket.getLogs(callsTo('writeln')).verify(happenedExactly(3));
      expect(socket.getLogs(callsTo('writeln')).logs[0].args, equals(["$command :${sbMessagePart1.toString()}"]));
      expect(socket.getLogs(callsTo('writeln')).logs[1].args, equals(["$command :${sbMessagePart2.toString()}"]));
      expect(socket.getLogs(callsTo('writeln')).logs[2].args, equals(["$command :${sbMessagePart3.toString()}"]));
    });

    test('should close properly, returning the socket', () {
      cnx._socket.when(callsTo('close')).thenReturn(new Future.value(cnx._socket));
      return cnx.close().then((value) {
        expect(value, equals(socket));
        socket.getLogs(callsTo('close')).verify(happenedOnce);
      });
    });

    test('throw if the socket was already closed', () {
      cnx._socket = null;
      return cnx.close().catchError((message) {
        expect(message, new isInstanceOf<String>());
      });
    });
  });
}

class MockSocket extends Mock implements Socket {}
