// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
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
    await _firestore.collection('config').doc('global').set(config.toMap());
  }

  Future<void> updateActiveMode(String mode) async {
    await _firestore.collection('config').doc('global').update({
      'activeMode': mode,
    });
  }

  Future<void> updateRekapSigned(bool signed) async {
    await _firestore.collection('config').doc('global').update({
      'rekapSigned': signed,
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
    await _firestore
        .collection('identities')
        .doc(identity.name)
        .set(identity.toMap());
  }

  Future<void> updateIdentitySignature(
    String name,
    String signatureVector,
  ) async {
    await _firestore.collection('identities').doc(name).update({
      'signatureVector': signatureVector,
      'allowSignatureReset': false, // Auto-revoke reset permission once updated
    });
  }

  Future<void> updateSignatureResetPermission(String name, bool allowed) async {
    await _firestore.collection('identities').doc(name).set({
      'allowSignatureReset': allowed,
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
    await _firestore
        .collection('groups')
        .doc(group.walikelas)
        .set(group.toMap());
  }

  Future<void> deleteGroup(String walikelas) async {
    await _firestore.collection('groups').doc(walikelas).delete();
  }

  Future<void> updateWalikelasSignature(
    String walikelasName,
    String signatureBase64,
  ) async {
    await _firestore.collection('groups').doc(walikelasName).update({
      'walikelasSignatureBase64': signatureBase64,
    });
  }

  Future<void> deleteIdentity(String name) async {
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
    await _firestore.collection('files').doc('$type-$id').set({
      'data': base64Data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String?> getFileBase64(String type, String id) async {
    final doc = await _firestore.collection('files').doc('$type-$id').get();
    if (doc.exists) {
      return doc.data()?['data'] as String?;
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
    await _firestore
        .collection('test_scores')
        .doc(docId)
        .set(testScore.toMap());
  }

  Stream<List<TestScore>> streamTestScores() {
    return _firestore.collection('test_scores').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => TestScore.fromMap(doc.data())).toList();
    });
  }

  // --- CERTIFICATE RECORDS ---
  Future<void> saveCertificateRecord(CertificateRecord record) async {
    await _firestore
        .collection('certificates')
        .doc(record.verificationCode)
        .set(record.toMap());
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
