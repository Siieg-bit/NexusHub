import 'package:flutter/material.dart';

class PostEditorType {
  static const String story = 'story';
  static const String question = 'question';
  static const String publicChat = 'public_chat';
  static const String image = 'image';
  static const String link = 'link';
  static const String quiz = 'quiz';
  static const String poll = 'poll';
  static const String wiki = 'wiki';
  static const String blog = 'blog';
  static const String draft = 'draft';
  static const String normal = 'normal';
  static const String qa = 'qa';

  static const List<String> all = [
    story,
    question,
    publicChat,
    image,
    link,
    quiz,
    poll,
    wiki,
    blog,
    draft,
    normal,
    qa,
  ];
}

class EditorTextStyleModel {
  final String textColor;
  final String? backgroundColor;
  final String? fontFamily;
  final double? fontSize;
  final bool bold;
  final bool italic;
  final bool underline;
  final String align;

  const EditorTextStyleModel({
    this.textColor = '#FFFFFFFF',
    this.backgroundColor,
    this.fontFamily,
    this.fontSize,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.align = 'left',
  });

  factory EditorTextStyleModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const EditorTextStyleModel();
    return EditorTextStyleModel(
      textColor: json['text_color'] as String? ?? '#FFFFFFFF',
      backgroundColor: json['background_color'] as String?,
      fontFamily: json['font_family'] as String?,
      fontSize: (json['font_size'] as num?)?.toDouble(),
      bold: json['bold'] == true,
      italic: json['italic'] == true,
      underline: json['underline'] == true,
      align: json['align'] as String? ?? 'left',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text_color': textColor,
      if (backgroundColor != null) 'background_color': backgroundColor,
      if (fontFamily != null) 'font_family': fontFamily,
      if (fontSize != null) 'font_size': fontSize,
      'bold': bold,
      'italic': italic,
      'underline': underline,
      'align': align,
    };
  }

  EditorTextStyleModel copyWith({
    String? textColor,
    String? backgroundColor,
    String? fontFamily,
    double? fontSize,
    bool? bold,
    bool? italic,
    bool? underline,
    String? align,
  }) {
    return EditorTextStyleModel(
      textColor: textColor ?? this.textColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      align: align ?? this.align,
    );
  }
}

class EditorDividerStyleModel {
  final String style;
  final String color;
  final double thickness;
  final double spacing;
  final bool inset;

  const EditorDividerStyleModel({
    this.style = 'solid',
    this.color = '#33FFFFFF',
    this.thickness = 1,
    this.spacing = 20,
    this.inset = false,
  });

  factory EditorDividerStyleModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const EditorDividerStyleModel();
    return EditorDividerStyleModel(
      style: json['style'] as String? ?? 'solid',
      color: json['color'] as String? ?? '#33FFFFFF',
      thickness: (json['thickness'] as num?)?.toDouble() ?? 1,
      spacing: (json['spacing'] as num?)?.toDouble() ?? 20,
      inset: json['inset'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'style': style,
      'color': color,
      'thickness': thickness,
      'spacing': spacing,
      'inset': inset,
    };
  }

  EditorDividerStyleModel copyWith({
    String? style,
    String? color,
    double? thickness,
    double? spacing,
    bool? inset,
  }) {
    return EditorDividerStyleModel(
      style: style ?? this.style,
      color: color ?? this.color,
      thickness: thickness ?? this.thickness,
      spacing: spacing ?? this.spacing,
      inset: inset ?? this.inset,
    );
  }
}

class EditorCoverStyleModel {
  final String? coverImageUrl;
  final String? backgroundImageUrl;
  final String? backgroundColor;
  final String? surfaceColor;
  final double surfaceOpacity;
  final bool blurBackground;

  const EditorCoverStyleModel({
    this.coverImageUrl,
    this.backgroundImageUrl,
    this.backgroundColor,
    this.surfaceColor,
    this.surfaceOpacity = 0.18,
    this.blurBackground = false,
  });

  factory EditorCoverStyleModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const EditorCoverStyleModel();
    return EditorCoverStyleModel(
      coverImageUrl: json['cover_image_url'] as String?,
      backgroundImageUrl: json['background_image_url'] as String?,
      backgroundColor: json['background_color'] as String?,
      surfaceColor: json['surface_color'] as String?,
      surfaceOpacity: (json['surface_opacity'] as num?)?.toDouble() ?? 0.18,
      blurBackground: json['blur_background'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
      if (backgroundImageUrl != null) 'background_image_url': backgroundImageUrl,
      if (backgroundColor != null) 'background_color': backgroundColor,
      if (surfaceColor != null) 'surface_color': surfaceColor,
      'surface_opacity': surfaceOpacity,
      'blur_background': blurBackground,
    };
  }

  EditorCoverStyleModel copyWith({
    String? coverImageUrl,
    String? backgroundImageUrl,
    String? backgroundColor,
    String? surfaceColor,
    double? surfaceOpacity,
    bool? blurBackground,
  }) {
    return EditorCoverStyleModel(
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      backgroundImageUrl: backgroundImageUrl ?? this.backgroundImageUrl,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      surfaceOpacity: surfaceOpacity ?? this.surfaceOpacity,
      blurBackground: blurBackground ?? this.blurBackground,
    );
  }
}

class EditorPollOptionModel {
  final String id;
  final String text;
  final String? imageUrl;
  final String? color;

  const EditorPollOptionModel({
    required this.id,
    required this.text,
    this.imageUrl,
    this.color,
  });

  factory EditorPollOptionModel.fromJson(Map<String, dynamic> json) {
    return EditorPollOptionModel(
      id: json['id'] as String? ?? UniqueKey().toString(),
      text: json['text'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      color: json['color'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      if (imageUrl != null) 'image_url': imageUrl,
      if (color != null) 'color': color,
    };
  }
}

class EditorQuizQuestionModel {
  final String id;
  final String prompt;
  final List<EditorPollOptionModel> options;
  final int correctIndex;
  final String? explanation;

  const EditorQuizQuestionModel({
    required this.id,
    required this.prompt,
    this.options = const [],
    this.correctIndex = 0,
    this.explanation,
  });

  factory EditorQuizQuestionModel.fromJson(Map<String, dynamic> json) {
    return EditorQuizQuestionModel(
      id: json['id'] as String? ?? UniqueKey().toString(),
      prompt: json['prompt'] as String? ?? json['question_text'] as String? ?? '',
      options: (json['options'] as List<dynamic>? ?? const [])
          .map((e) => EditorPollOptionModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      correctIndex: (json['correct_index'] as num?)?.toInt() ??
          (json['correct_option_index'] as num?)?.toInt() ??
          0,
      explanation: json['explanation'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prompt': prompt,
      'question_text': prompt,
      'options': options.map((e) => e.toJson()).toList(),
      'correct_index': correctIndex,
      'correct_option_index': correctIndex,
      if (explanation != null) 'explanation': explanation,
    };
  }
}

class PostEditorModel {
  final String editorType;
  final String? variant;
  final EditorTextStyleModel titleStyle;
  final EditorTextStyleModel subtitleStyle;
  final EditorTextStyleModel bodyStyle;
  final EditorDividerStyleModel dividerStyle;
  final EditorCoverStyleModel coverStyle;
  final List<EditorPollOptionModel> pollOptions;
  final List<EditorQuizQuestionModel> quizQuestions;
  final Map<String, dynamic> storySettings;
  final Map<String, dynamic> chatSettings;
  final Map<String, dynamic> wikiSettings;
  final Map<String, dynamic> blogSettings;
  final Map<String, dynamic> extra;

  const PostEditorModel({
    this.editorType = PostEditorType.normal,
    this.variant,
    this.titleStyle = const EditorTextStyleModel(
      fontSize: 24,
      bold: true,
      textColor: '#FFFFFFFF',
    ),
    this.subtitleStyle = const EditorTextStyleModel(
      fontSize: 16,
      textColor: '#CCFFFFFF',
    ),
    this.bodyStyle = const EditorTextStyleModel(
      fontSize: 16,
      textColor: '#FFF5F5F5',
    ),
    this.dividerStyle = const EditorDividerStyleModel(),
    this.coverStyle = const EditorCoverStyleModel(),
    this.pollOptions = const [],
    this.quizQuestions = const [],
    this.storySettings = const {},
    this.chatSettings = const {},
    this.wikiSettings = const {},
    this.blogSettings = const {},
    this.extra = const {},
  });

  factory PostEditorModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PostEditorModel();
    return PostEditorModel(
      editorType: json['editor_type'] as String? ?? PostEditorType.normal,
      variant: json['variant'] as String?,
      titleStyle: EditorTextStyleModel.fromJson(
        json['title_style'] as Map<String, dynamic>?,
      ),
      subtitleStyle: EditorTextStyleModel.fromJson(
        json['subtitle_style'] as Map<String, dynamic>?,
      ),
      bodyStyle: EditorTextStyleModel.fromJson(
        json['body_style'] as Map<String, dynamic>?,
      ),
      dividerStyle: EditorDividerStyleModel.fromJson(
        json['divider_style'] as Map<String, dynamic>?,
      ),
      coverStyle: EditorCoverStyleModel.fromJson(
        json['cover_style'] as Map<String, dynamic>?,
      ),
      pollOptions: (json['poll_options'] as List<dynamic>? ?? const [])
          .map((e) => EditorPollOptionModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      quizQuestions: (json['quiz_questions'] as List<dynamic>? ?? const [])
          .map((e) => EditorQuizQuestionModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      storySettings: Map<String, dynamic>.from(
        json['story_settings'] as Map? ?? const {},
      ),
      chatSettings: Map<String, dynamic>.from(
        json['chat_settings'] as Map? ?? const {},
      ),
      wikiSettings: Map<String, dynamic>.from(
        json['wiki_settings'] as Map? ?? const {},
      ),
      blogSettings: Map<String, dynamic>.from(
        json['blog_settings'] as Map? ?? const {},
      ),
      extra: Map<String, dynamic>.from(json['extra'] as Map? ?? const {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'editor_type': editorType,
      if (variant != null) 'variant': variant,
      'title_style': titleStyle.toJson(),
      'subtitle_style': subtitleStyle.toJson(),
      'body_style': bodyStyle.toJson(),
      'divider_style': dividerStyle.toJson(),
      'cover_style': coverStyle.toJson(),
      'poll_options': pollOptions.map((e) => e.toJson()).toList(),
      'quiz_questions': quizQuestions.map((e) => e.toJson()).toList(),
      'story_settings': storySettings,
      'chat_settings': chatSettings,
      'wiki_settings': wikiSettings,
      'blog_settings': blogSettings,
      'extra': extra,
    };
  }

  PostEditorModel copyWith({
    String? editorType,
    String? variant,
    EditorTextStyleModel? titleStyle,
    EditorTextStyleModel? subtitleStyle,
    EditorTextStyleModel? bodyStyle,
    EditorDividerStyleModel? dividerStyle,
    EditorCoverStyleModel? coverStyle,
    List<EditorPollOptionModel>? pollOptions,
    List<EditorQuizQuestionModel>? quizQuestions,
    Map<String, dynamic>? storySettings,
    Map<String, dynamic>? chatSettings,
    Map<String, dynamic>? wikiSettings,
    Map<String, dynamic>? blogSettings,
    Map<String, dynamic>? extra,
  }) {
    return PostEditorModel(
      editorType: editorType ?? this.editorType,
      variant: variant ?? this.variant,
      titleStyle: titleStyle ?? this.titleStyle,
      subtitleStyle: subtitleStyle ?? this.subtitleStyle,
      bodyStyle: bodyStyle ?? this.bodyStyle,
      dividerStyle: dividerStyle ?? this.dividerStyle,
      coverStyle: coverStyle ?? this.coverStyle,
      pollOptions: pollOptions ?? this.pollOptions,
      quizQuestions: quizQuestions ?? this.quizQuestions,
      storySettings: storySettings ?? this.storySettings,
      chatSettings: chatSettings ?? this.chatSettings,
      wikiSettings: wikiSettings ?? this.wikiSettings,
      blogSettings: blogSettings ?? this.blogSettings,
      extra: extra ?? this.extra,
    );
  }
}
