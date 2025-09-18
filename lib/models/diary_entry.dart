import 'package:hive/hive.dart';

import 'meal_category.dart';

class DiaryEntry extends HiveObject {
  DiaryEntry({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.timestamp,
    required this.goal,
    required this.advice,
    required this.category,
    this.note,
    this.imagePath,
    this.labels,
  });

  String id;
  String name;
  double calories;
  double protein;
  double fat;
  double carbs;
  DateTime timestamp;
  String goal;
  String advice;
  MealCategory category;
  String? note;
  String? imagePath;
  List<String>? labels;
}

class DiaryEntryAdapter extends TypeAdapter<DiaryEntry> {
  @override
  final int typeId = 0;

  @override
  DiaryEntry read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    final count = reader.readByte();
    for (var i = 0; i < count; i++) {
      final key = reader.readByte();
      fields[key] = reader.read();
    }
    return DiaryEntry(
      id: fields[0] as String,
      name: fields[1] as String,
      calories: (fields[2] as num).toDouble(),
      protein: (fields[3] as num).toDouble(),
      fat: (fields[4] as num).toDouble(),
      carbs: (fields[5] as num).toDouble(),
      timestamp: fields[6] as DateTime,
      goal: fields[7] as String,
      advice: fields[8] as String,
      note: fields[9] as String?,
      category: MealCategoryExt.fromStorage(fields[10] as String?),
      imagePath: fields[11] as String?,
      labels: (fields[12] as List?)?.map((dynamic e) => e.toString()).toList(),
    );
  }

  @override
  void write(BinaryWriter writer, DiaryEntry obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.calories)
      ..writeByte(3)
      ..write(obj.protein)
      ..writeByte(4)
      ..write(obj.fat)
      ..writeByte(5)
      ..write(obj.carbs)
      ..writeByte(6)
      ..write(obj.timestamp)
      ..writeByte(7)
      ..write(obj.goal)
      ..writeByte(8)
      ..write(obj.advice)
      ..writeByte(9)
      ..write(obj.note)
      ..writeByte(10)
      ..write(obj.category.storageValue)
      ..writeByte(11)
      ..write(obj.imagePath)
      ..writeByte(12)
      ..write(obj.labels);
  }
}
