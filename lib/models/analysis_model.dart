class AnalysisResponse {
  final SpeakerAnalysis speakerAnalysis;
  final QualityScores qualityScores;
  final TranscriptionMetrics transcriptionMetrics;
  final String fullTranscription;
  final List<WordAnalysis> wordAnalysis;

  AnalysisResponse({
    required this.speakerAnalysis,
    required this.qualityScores,
    required this.transcriptionMetrics,
    required this.fullTranscription,
    required this.wordAnalysis,
  });

  factory AnalysisResponse.fromJson(Map<String, dynamic> json) {
    return AnalysisResponse(
      speakerAnalysis: SpeakerAnalysis.fromJson(json['speaker_analysis']),
      qualityScores: QualityScores.fromJson(json['quality_scores']),
      transcriptionMetrics: TranscriptionMetrics.fromJson(json['transcription_metrics']),
      fullTranscription: json['full_transcription'] ?? '',
      wordAnalysis: (json['word_analysis'] as List)
          .map((i) => WordAnalysis.fromJson(i))
          .toList(),
    );
  }
}

class SpeakerAnalysis {
  final String predictedAgeGroup;
  final String confidence;

  SpeakerAnalysis({required this.predictedAgeGroup, required this.confidence});

  factory SpeakerAnalysis.fromJson(Map<String, dynamic> json) {
    return SpeakerAnalysis(
      predictedAgeGroup: json['predicted_age_group'] ?? 'Unknown',
      confidence: json['confidence'] ?? '0',
    );
  }
}

class QualityScores {
  final double overallScore;
  final double fluency;
  final double pronunciation;
  final double clarity;

  QualityScores({
    required this.overallScore,
    required this.fluency,
    required this.pronunciation,
    required this.clarity,
  });

  factory QualityScores.fromJson(Map<String, dynamic> json) {
    return QualityScores(
      overallScore: double.tryParse(json['overall_score'].toString()) ?? 0.0,
      fluency: double.tryParse(json['fluency'].toString()) ?? 0.0,
      pronunciation: double.tryParse(json['pronunciation'].toString()) ?? 0.0,
      clarity: double.tryParse(json['clarity'].toString()) ?? 0.0,
    );
  }
}

class TranscriptionMetrics {
  final String wpm;
  final String accuracy;

  TranscriptionMetrics({required this.wpm, required this.accuracy});

  factory TranscriptionMetrics.fromJson(Map<String, dynamic> json) {
    return TranscriptionMetrics(
      wpm: json['words_per_minute'] ?? '0',
      accuracy: json['accuracy_from_wer'] ?? '0%',
    );
  }
}

class WordAnalysis {
  final String text;
  final String color; // "green", "red", "black", "gray"
  final String status;

  WordAnalysis({required this.text, required this.color, required this.status});

  factory WordAnalysis.fromJson(Map<String, dynamic> json) {
    return WordAnalysis(
      text: json['text'] ?? '',
      color: json['color'] ?? 'black',
      status: json['status'] ?? 'unknown',
    );
  }
}