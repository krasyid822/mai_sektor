// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models.dart';

/// Logs a message to the browser console (visible in DevTools > Console).
void _consoleLog(Object message) {
  html.window.console.log('[FirebaseService] $message');
}

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

class FirebaseService {
  final FirebaseFirestore _firestore;

  FirebaseService(this._firestore);

  // --- CONFIGURATION ---
  Stream<AppConfig?> streamConfig() {
    return _firestore
        .collection('config')
        .doc('global')
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists || snapshot.data() == null) return null;
          return AppConfig.fromMap(snapshot.data()!);
        })
        .handleError((e, stack) {
          _consoleLog('streamConfig error: $e\n$stack');
        });
  }

  Future<void> saveConfig(AppConfig config) async {
    final data = config.toMap();
    data['confirmedByUser'] = true;
    await _firestore.collection('config').doc('global').set(data);
  }

  Future<void> updateActiveMode(String mode) async {
    await _firestore.collection('config').doc('global').update({
      'activeMode': mode,
      'confirmedByUser': true,
    });
  }

  Future<void> updateRekapSigned(bool signed) async {
    await _firestore.collection('config').doc('global').update({
      'rekapSigned': signed,
      'confirmedByUser': true,
    });
  }

  // --- IDENTITIES ---
  Stream<List<Identity>> streamIdentities() {
    return _firestore
        .collection('identities')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Identity.fromMap(doc.data()))
              .toList();
        })
        .handleError((e, stack) {
          _consoleLog('streamIdentities error: $e\n$stack');
        });
  }

  Future<void> saveIdentity(Identity identity) async {
    final data = identity.toMap();
    data['confirmedByUser'] = true;
    await _firestore
        .collection('identities')
        .doc(identity.name)
        .set(data);
  }

  Future<void> updateIdentitySignature(
    String name,
    String signatureVector,
  ) async {
    await _firestore.collection('identities').doc(name).update({
      'signatureVector': signatureVector,
      'allowSignatureReset': false, // Auto-revoke reset permission once updated
      'confirmedByUser': true,
    });
  }

  Future<void> updateSignatureResetPermission(String name, bool allowed) async {
    await _firestore.collection('identities').doc(name).set({
      'allowSignatureReset': allowed,
      'confirmedByUser': true,
    }, SetOptions(merge: true));
  }

  // --- GROUPS ---
  Stream<List<Group>> streamGroups() {
    return _firestore
        .collection('groups')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Group.fromMap(doc.data())).toList();
        })
        .handleError((e, stack) {
          _consoleLog('streamGroups error: $e\n$stack');
        });
  }

  Future<void> saveGroup(Group group) async {
    final data = group.toMap();
    data['confirmedByUser'] = true;
    await _firestore
        .collection('groups')
        .doc(group.walikelas)
        .set(data);
  }

  Future<void> deleteGroup(String walikelas) async {
    await _firestore.collection('groups').doc(walikelas).update({
      'deleteConfirmed': true,
      'confirmedByUser': true,
    });
    await _firestore.collection('groups').doc(walikelas).delete();
  }

  Future<void> updateWalikelasSignature(
    String walikelasName,
    String signatureBase64,
  ) async {
    await _firestore.collection('groups').doc(walikelasName).update({
      'walikelasSignatureBase64': signatureBase64,
      'confirmedByUser': true,
    });
  }

  Future<void> deleteIdentity(String name) async {
    await _firestore.collection('identities').doc(name).update({
      'deleteConfirmed': true,
      'confirmedByUser': true,
    });
    await _firestore.collection('identities').doc(name).delete();
  }

  // --- ATTENDANCE ---
  Stream<List<Attendance>> streamAttendance() {
    return _firestore
        .collection('attendance')
        .orderBy('checkInTime', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Attendance.fromMap(doc.id, doc.data()))
              .toList();
        })
        .handleError((e, stack) {
          _consoleLog('streamAttendance error: $e\n$stack');
        });
  }

  Future<void> addAttendance(Attendance attendance) async {
    await _firestore.collection('attendance').add(attendance.toMap());
  }

  // --- TESTS ---
  Stream<List<Test>> streamTests() {
    return _firestore
        .collection('tests')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Test.fromMap(doc.id, doc.data()))
              .toList();
        })
        .handleError((e, stack) {
          _consoleLog('streamTests error: $e\n$stack');
        });
  }

  Future<void> addTest(Test test) async {
    await _firestore.collection('tests').add(test.toMap());
  }

  // --- ROOM QUDWAH EVALUATIONS ---
  Stream<List<RoomQudwahEvaluation>> streamEvaluations() {
    return _firestore
        .collection('evaluations')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => RoomQudwahEvaluation.fromMap(doc.id, doc.data()))
              .toList();
        })
        .handleError((e, stack) {
          _consoleLog('streamEvaluations error: $e\n$stack');
        });
  }

  Future<void> addEvaluation(RoomQudwahEvaluation evaluation) async {
    await _firestore.collection('evaluations').add(evaluation.toMap());
  }

  // --- PDF UPLOADS (stored as Base64 in Firestore to comply with base64 storage request) ---
  Future<void> saveFileBase64(String type, String id, String base64Data) async {
    String finalData = base64Data;
    try {
      final completer = Completer<String>();
      // ignore: undefined_function
      final jsCallback = js.allowInterop((dynamic res) {
        completer.complete(res as String);
      });
      js.context.callMethod('compressBase64DataCallback', [base64Data, jsCallback]);
      finalData = await completer.future;
    } catch (e) {
      _consoleLog('Failed to compress base64 data: $e');
    }

    final docRef = _firestore.collection('files').doc('$type-$id');

    if (finalData.length <= 800000) {
      await docRef.set({
        'data': finalData,
        'chunkCount': null,
        'updatedAt': FieldValue.serverTimestamp(),
        'confirmedByUser': true,
      });
    } else {
      const int chunkSize = 700000;
      final int totalLength = finalData.length;
      final List<String> chunks = [];
      for (int i = 0; i < totalLength; i += chunkSize) {
        final int end = (i + chunkSize < totalLength) ? i + chunkSize : totalLength;
        chunks.add(finalData.substring(i, end));
      }

      final WriteBatch batch = _firestore.batch();
      for (int i = 0; i < chunks.length; i++) {
        final chunkRef = docRef.collection('chunks').doc('$i');
        batch.set(chunkRef, {
          'data': chunks[i],
          'confirmedByUser': true,
        });
      }
      await batch.commit();

      await docRef.set({
        'data': null,
        'chunkCount': chunks.length,
        'updatedAt': FieldValue.serverTimestamp(),
        'confirmedByUser': true,
      });
    }
  }

  Future<String?> getFileBase64(String type, String id) async {
    final docRef = _firestore.collection('files').doc('$type-$id');
    final doc = await docRef.get();
    if (doc.exists) {
      final int? chunkCount = doc.data()?['chunkCount'] as int?;
      String? rawData;

      if (chunkCount != null && chunkCount > 0) {
        final List<Future<DocumentSnapshot<Map<String, dynamic>>>> futures = [];
        for (int i = 0; i < chunkCount; i++) {
          futures.add(docRef.collection('chunks').doc('$i').get());
        }
        final List<DocumentSnapshot<Map<String, dynamic>>> snapshots = await Future.wait(futures);
        final StringBuffer buffer = StringBuffer();
        for (final snapshot in snapshots) {
          if (snapshot.exists) {
            final chunkData = snapshot.data()?['data'] as String?;
            if (chunkData != null) {
              buffer.write(chunkData);
            }
          }
        }
        rawData = buffer.toString();
      } else {
        rawData = doc.data()?['data'] as String?;
      }

      if (rawData != null) {
        try {
          final completer = Completer<String>();
          // ignore: undefined_function
          final jsCallback = js.allowInterop((dynamic res) {
            completer.complete(res as String);
          });
          js.context.callMethod('decompressBase64DataCallback', [rawData, jsCallback]);
          return await completer.future;
        } catch (e) {
          _consoleLog('Failed to decompress base64 data: $e');
          return rawData;
        }
      }
    }
    return null;
  }

  Stream<List<String>> streamUploadedFiles() {
    return _firestore
        .collection('files')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => doc.id).toList();
        })
        .handleError((e, stack) {
          _consoleLog('streamUploadedFiles error: $e\n$stack');
        });
  }

  Future<void> saveResumeScore(String participantName, double score) async {
    await _firestore.collection('resume_scores').doc(participantName).set({
      'score': score,
      'updatedAt': FieldValue.serverTimestamp(),
      'confirmedByUser': true,
    });
  }

  Stream<Map<String, double>> streamResumeScores() {
    return _firestore
        .collection('resume_scores')
        .snapshots()
        .map((snapshot) {
          final map = <String, double>{};
          for (final doc in snapshot.docs) {
            final val = doc.data()['score'];
            if (val != null) {
              map[doc.id] = (val as num).toDouble();
            }
          }
          return map;
        })
        .handleError((e, stack) {
          _consoleLog('streamResumeScores error: $e\n$stack');
        });
  }

  // --- TEST SCORES (headmaster input) ---
  Future<void> saveTestScore(TestScore testScore) async {
    final docId = '${testScore.participantName}_${testScore.materi}';
    final data = testScore.toMap();
    data['confirmedByUser'] = true;
    await _firestore
        .collection('test_scores')
        .doc(docId)
        .set(data);
  }

  Stream<List<TestScore>> streamTestScores() {
    return _firestore.collection('test_scores').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => TestScore.fromMap(doc.data())).toList();
    });
  }

  // --- CERTIFICATE RECORDS ---
  Future<void> saveCertificateRecord(CertificateRecord record) async {
    final data = record.toMap();
    data['confirmedByUser'] = true;
    await _firestore
        .collection('certificates')
        .doc(record.verificationCode)
        .set(data);
  }

  Future<CertificateRecord?> getCertificateRecord(
    String verificationCode,
  ) async {
    final doc = await _firestore
        .collection('certificates')
        .doc(verificationCode)
        .get();
    if (doc.exists && doc.data() != null) {
      return CertificateRecord.fromMap(doc.data()!);
    }
    return null;
  }

  // --- SYSTEM REPORTS ---
  Future<void> addSystemReport(SystemReport report) async {
    await _firestore.collection('system_reports').add(report.toMap());
  }

  Future<void> deleteSystemReport(String id) async {
    await _firestore.collection('system_reports').doc(id).update({
      'deleteConfirmed': true,
      'confirmedByUser': true,
    });
    await _firestore.collection('system_reports').doc(id).delete();
  }

  Future<void> reportSystemException({
    required String reporterName,
    required String role,
    required String formSource,
    required Object exception,
    StackTrace? stackTrace,
  }) async {
    try {
      final report = SystemReport(
        id: '',
        reporterName: reporterName.isEmpty ? 'System Auto-Report' : reporterName,
        role: role.isEmpty ? 'system' : role,
        formSource: formSource,
        description: 'Error: $exception\n\nStacktrace:\n${stackTrace ?? StackTrace.current}',
        timestamp: DateTime.now(),
      );
      await addSystemReport(report);
    } catch (e) {
      _consoleLog('Failed to auto-report exception: $e');
    }
  }

  Stream<List<SystemReport>> streamSystemReports() {
    return _firestore
        .collection('system_reports')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => SystemReport.fromMap(doc.id, doc.data()))
              .toList();
        })
        .handleError((e, stack) {
          _consoleLog('streamSystemReports error: $e\n$stack');
        });
  }
}

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return FirebaseService(firestore);
});

final configStreamProvider = StreamProvider<AppConfig?>((ref) {
  return ref.watch(firebaseServiceProvider).streamConfig();
});

final identitiesStreamProvider = StreamProvider<List<Identity>>((ref) {
  return ref.watch(firebaseServiceProvider).streamIdentities();
});

final groupsStreamProvider = StreamProvider<List<Group>>((ref) {
  return ref.watch(firebaseServiceProvider).streamGroups();
});

final attendanceStreamProvider = StreamProvider<List<Attendance>>((ref) {
  return ref.watch(firebaseServiceProvider).streamAttendance();
});

final testsStreamProvider = StreamProvider<List<Test>>((ref) {
  return ref.watch(firebaseServiceProvider).streamTests();
});

final evaluationsStreamProvider = StreamProvider<List<RoomQudwahEvaluation>>((
  ref,
) {
  return ref.watch(firebaseServiceProvider).streamEvaluations();
});

final filesStreamProvider = StreamProvider<List<String>>((ref) {
  return ref.watch(firebaseServiceProvider).streamUploadedFiles();
});

final resumeScoresStreamProvider = StreamProvider<Map<String, double>>((ref) {
  return ref.watch(firebaseServiceProvider).streamResumeScores();
});

final testScoresStreamProvider = StreamProvider<List<TestScore>>((ref) {
  return ref.watch(firebaseServiceProvider).streamTestScores();
});

final systemReportsStreamProvider = StreamProvider<List<SystemReport>>((ref) {
  return ref.watch(firebaseServiceProvider).streamSystemReports();
});

class SessionAuthNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void login() => state = true;
  void logout() => state = false;
}

final sessionAuthStateProvider = NotifierProvider<SessionAuthNotifier, bool>(
  SessionAuthNotifier.new,
);
