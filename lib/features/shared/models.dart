import 'package:cloud_firestore/cloud_firestore.dart';

class Identity {
  final String name;
  final String? signatureVector; // base64 or coordinate points representation
  final String? murobbi;
  final String? whatsapp;
  final String? gender; // 'ikhwan' or 'akhwat'
  final String? faceVector; // facial descriptors representation
  final bool allowSignatureReset;

  Identity({
    required this.name,
    this.signatureVector,
    this.murobbi,
    this.whatsapp,
    this.gender,
    this.faceVector,
    this.allowSignatureReset = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'signatureVector': signatureVector,
      'murobbi': murobbi,
      'whatsapp': whatsapp,
      'gender': gender,
      'faceVector': faceVector,
      'allowSignatureReset': allowSignatureReset,
    };
  }

  factory Identity.fromMap(Map<String, dynamic> map) {
    return Identity(
      name: map['name'] ?? '',
      signatureVector: map['signatureVector'],
      murobbi: map['murobbi'],
      whatsapp: map['whatsapp'],
      gender: map['gender'],
      faceVector: map['faceVector'],
      allowSignatureReset: map['allowSignatureReset'] ?? false,
    );
  }
}

class Group {
  final String walikelas;
  final List<String> participants;
  final String? walikelasSignatureBase64;

  Group({
    required this.walikelas,
    required this.participants,
    this.walikelasSignatureBase64,
  });

  Map<String, dynamic> toMap() {
    return {
      'walikelas': walikelas,
      'participants': participants,
      'walikelasSignatureBase64': walikelasSignatureBase64,
    };
  }

  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      walikelas: map['walikelas'] ?? '',
      participants: List<String>.from(map['participants'] ?? []),
      walikelasSignatureBase64: map['walikelasSignatureBase64'],
    );
  }
}

class Attendance {
  final String id;
  final String identityName;
  final String role; // 'peserta', 'guru', 'tamu'
  final DateTime checkInTime;
  final String? signatureBase64;
  final String? faceVector;
  final String? errorReport;
  final String? materi;

  Attendance({
    required this.id,
    required this.identityName,
    required this.role,
    required this.checkInTime,
    this.signatureBase64,
    this.faceVector,
    this.errorReport,
    this.materi,
  });

  Map<String, dynamic> toMap() {
    return {
      'identityName': identityName,
      'role': role,
      'checkInTime': Timestamp.fromDate(checkInTime),
      'signatureBase64': signatureBase64,
      'faceVector': faceVector,
      'errorReport': errorReport,
      'materi': materi,
    };
  }

  factory Attendance.fromMap(String id, Map<String, dynamic> map) {
    return Attendance(
      id: id,
      identityName: map['identityName'] ?? '',
      role: map['role'] ?? 'peserta',
      checkInTime:
          (map['checkInTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      signatureBase64: map['signatureBase64'],
      faceVector: map['faceVector'],
      errorReport: map['errorReport'],
      materi: map['materi'],
    );
  }
}

class Test {
  final String id;
  final String type; // 'pre' or 'post'
  final String name;
  final String materi;
  final String pemateri;
  final String instruktur;
  final Map<String, dynamic> answers;
  final int? score;

  Test({
    required this.id,
    required this.type,
    required this.name,
    required this.materi,
    required this.pemateri,
    required this.instruktur,
    required this.answers,
    this.score,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'name': name,
      'materi': materi,
      'pemateri': pemateri,
      'instruktur': instruktur,
      'answers': answers,
      'score': score,
    };
  }

  factory Test.fromMap(String id, Map<String, dynamic> map) {
    return Test(
      id: id,
      type: map['type'] ?? 'pre',
      name: map['name'] ?? '',
      materi: map['materi'] ?? '',
      pemateri: map['pemateri'] ?? '',
      instruktur: map['instruktur'] ?? '',
      answers: Map<String, dynamic>.from(map['answers'] ?? {}),
      score: map['score'],
    );
  }
}

class RoomQudwahEvaluation {
  final String id;
  final String walikelas;
  final String peserta;
  final String materi;
  final int pertemuanKe;
  final Map<String, int> scores; // 14 items
  final Map<String, String> comments; // 14 items
  final String signatureBase64;

  RoomQudwahEvaluation({
    required this.id,
    required this.walikelas,
    required this.peserta,
    required this.materi,
    required this.pertemuanKe,
    required this.scores,
    required this.comments,
    required this.signatureBase64,
  });

  Map<String, dynamic> toMap() {
    return {
      'walikelas': walikelas,
      'peserta': peserta,
      'materi': materi,
      'pertemuanKe': pertemuanKe,
      'scores': scores,
      'comments': comments,
      'signatureBase64': signatureBase64,
    };
  }

  factory RoomQudwahEvaluation.fromMap(String id, Map<String, dynamic> map) {
    return RoomQudwahEvaluation(
      id: id,
      walikelas: map['walikelas'] ?? '',
      peserta: map['peserta'] ?? '',
      materi: map['materi'] ?? '',
      pertemuanKe: map['pertemuanKe'] ?? 1,
      scores: Map<String, int>.from(map['scores'] ?? {}),
      comments: Map<String, String>.from(map['comments'] ?? {}),
      signatureBase64: map['signatureBase64'] ?? '',
    );
  }
}

class AppConfig {
  final String activeMode; // 'absensi', 'pretest', 'posttest', 'kontrak', 'idle'
  final String kepalaSekolahNama;
  final String kepengurusanTahun;
  final double bobotKelasBesar;
  final double bobotRoomQudwah;
  final double bobotTugas;
  final double nilaiMinimum;
  final String? kepsekSignatureBase64;
  final String? kadivNama;
  final String? kadivSignatureBase64;
  final String activeMateri;

  AppConfig({
    required this.activeMode,
    required this.kepalaSekolahNama,
    required this.kepengurusanTahun,
    required this.bobotKelasBesar,
    required this.bobotRoomQudwah,
    required this.bobotTugas,
    required this.nilaiMinimum,
    this.kepsekSignatureBase64,
    this.kadivNama,
    this.kadivSignatureBase64,
    this.activeMateri = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'activeMode': activeMode,
      'kepalaSekolahNama': kepalaSekolahNama,
      'kepengurusanTahun': kepengurusanTahun,
      'bobotKelasBesar': bobotKelasBesar,
      'bobotRoomQudwah': bobotRoomQudwah,
      'bobotTugas': bobotTugas,
      'nilaiMinimum': nilaiMinimum,
      'kepsekSignatureBase64': kepsekSignatureBase64,
      'kadivNama': kadivNama,
      'kadivSignatureBase64': kadivSignatureBase64,
      'activeMateri': activeMateri,
    };
  }

  factory AppConfig.fromMap(Map<String, dynamic> map) {
    return AppConfig(
      activeMode: map['activeMode'] ?? 'idle',
      kepalaSekolahNama: map['kepalaSekolahNama'] ?? '',
      kepengurusanTahun: map['kepengurusanTahun'] ?? '',
      bobotKelasBesar: (map['bobotKelasBesar'] as num?)?.toDouble() ?? 40.0,
      bobotRoomQudwah: (map['bobotRoomQudwah'] as num?)?.toDouble() ?? 40.0,
      bobotTugas: (map['bobotTugas'] as num?)?.toDouble() ?? 20.0,
      nilaiMinimum: (map['nilaiMinimum'] as num?)?.toDouble() ?? 75.0,
      kepsekSignatureBase64: map['kepsekSignatureBase64'],
      kadivNama: map['kadivNama'],
      kadivSignatureBase64: map['kadivSignatureBase64'],
      activeMateri: map['activeMateri'] ?? '',
    );
  }
}
