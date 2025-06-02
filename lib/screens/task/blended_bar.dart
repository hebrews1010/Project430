
import 'package:flutter/material.dart';
import 'dart:math';


class BlendedBar extends StatelessWidget {
  final int greenNum;
  final int yellowNum;
  final int redNum;
  final int totalStates;

  const BlendedBar({
    Key? key,
    required this.greenNum,
    required this.yellowNum,
    required this.redNum,
    required this.totalStates,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double totalUnits = (greenNum + yellowNum + redNum).toDouble();

    if (totalUnits == 0 || totalStates == 0) {
      return const SizedBox(height: 12.0);
    }

    // ListTile 내부에서는 MediaQuery.of(context).size.width가 전체 화면 너비일 수 있으므로,
    // 실제 사용 가능한 너비에 맞게 조정하는 것이 좋습니다.
    // 여기서는 LayoutBuilder를 사용하거나 부모로부터 너비를 받는 것이 이상적이지만,
    // 원래 로직을 최대한 유지하기 위해 화면 너비 기반으로 계산합니다.
    // 실제 ListTile 항목의 너비는 이보다 작을 수 있습니다.
    final double availableWidth = MediaQuery.of(context).size.width * 0.9; // 예시: 화면 너비의 80%를 막대 너비로 가정
    final double totalBarWidth = (availableWidth / totalStates) * totalUnits;


    final Color greenActualColor = greenNum == totalStates && greenNum > 0
        ? Colors.grey
        : const Color(0xff93cf4f);
    final Color yellowActualColor = const Color(0xcfFDE767);
    final Color redActualColor = const Color(0x9fFF6868);

    List<Map<String, dynamic>> activeSegments = [];
    if (greenNum > 0) {
      activeSegments.add({'color': greenActualColor, 'num': greenNum});
    }
    if (yellowNum > 0) {
      activeSegments.add({'color': yellowActualColor, 'num': yellowNum});
    }
    if (redNum > 0) {
      activeSegments.add({'color': redActualColor, 'num': redNum});
    }

    if (activeSegments.isEmpty) {
      return const SizedBox(height: 12.0);
    }

    if (activeSegments.length == 1) {
      return Container(
        height: 12.0,
        width: totalBarWidth.isFinite && totalBarWidth > 0 ? totalBarWidth : null,
        color: activeSegments[0]['color'],
      );
    }

    List<Color> gradientColors = [];
    List<double> gradientStops = [];
    const double blendMarginFraction = 0.06; // 블렌드 영역 너비 (각 색상 경계의 절반)
    double cumulativeProportion = 0.0;

    for (int i = 0; i < activeSegments.length; i++) {
      Color currentColor = activeSegments[i]['color'];
      double proportion = activeSegments[i]['num'] / totalUnits;
      bool isFirstSegment = (i == 0);
      bool isLastSegment = (i == activeSegments.length - 1);
      double segmentStartPos = cumulativeProportion;
      double solidStartStop = isFirstSegment ? 0.0 : segmentStartPos + blendMarginFraction;
      double solidEndStop = isLastSegment ? 1.0 : (segmentStartPos + proportion) - blendMarginFraction;

      if (solidStartStop > solidEndStop) {
        double midPoint = segmentStartPos + proportion / 2;
        solidStartStop = midPoint;
        solidEndStop = midPoint;
      }
      solidStartStop = solidStartStop.clamp(0.0, 1.0);
      solidEndStop = solidEndStop.clamp(0.0, 1.0);

      if (isFirstSegment) {
        gradientColors.add(currentColor);
        gradientStops.add(solidStartStop);
      } else {
        if (gradientStops.isNotEmpty && solidStartStop > gradientStops.last + 0.00001) {
          gradientColors.add(currentColor);
          gradientStops.add(solidStartStop);
        } else if (gradientStops.isNotEmpty && gradientColors.last != currentColor) {
          gradientColors.last = currentColor;
        } else if (gradientStops.isEmpty){
          gradientColors.add(currentColor);
          gradientStops.add(solidStartStop);
        }
      }

      if (gradientStops.isNotEmpty && solidEndStop > gradientStops.last + 0.00001) {
        gradientColors.add(currentColor);
        gradientStops.add(solidEndStop);
      } else if (gradientStops.isNotEmpty && gradientColors.last != currentColor && solidEndStop == gradientStops.last) {
        gradientColors.last = currentColor;
      } else if (gradientStops.isEmpty && solidEndStop >= 0.0){
        gradientColors.add(currentColor);
        gradientStops.add(solidEndStop);
      }
      cumulativeProportion += proportion;
    }

    if (gradientStops.isEmpty && activeSegments.isNotEmpty) {
      gradientColors.add(activeSegments.first['color']);
      gradientStops.add(0.0);
      if (activeSegments.length > 1 || totalUnits > 0) {
        gradientColors.add(activeSegments.last['color']);
        gradientStops.add(1.0);
      } else {
        if(gradientColors.length == 1 && gradientStops.length == 1 && gradientStops.first == 0.0){
          gradientColors.add(gradientColors.first);
          gradientStops.add(1.0);
        }
      }
    } else if (gradientStops.isNotEmpty && gradientStops.last < 0.99999 && activeSegments.isNotEmpty) {
      if (gradientColors.last != activeSegments.last['color'] && gradientStops.last < 1.0) {
        gradientColors.add(activeSegments.last['color']);
        gradientStops.add(min(1.0, gradientStops.last + 0.00001));
      }
      gradientColors.add(activeSegments.last['color']);
      gradientStops.add(1.0);
    }

    if (gradientStops.length > 1) {
      List<MapEntry<double, Color>> entries = [];
      for (int i = 0; i < gradientStops.length; i++) {
        entries.add(MapEntry(gradientStops[i], gradientColors[i]));
      }
      entries.sort((a, b) => a.key.compareTo(b.key));

      List<Color> finalColors = [];
      List<double> finalStops = [];

      if (entries.isNotEmpty) {
        finalColors.add(entries.first.value);
        finalStops.add(entries.first.key.clamp(0.0, 1.0));

        for (int i = 1; i < entries.length; i++) {
          if ((entries[i].key - finalStops.last).abs() > 0.00001) {
            finalColors.add(entries[i].value);
            finalStops.add(entries[i].key.clamp(0.0, 1.0));
          } else {
            finalColors.last = entries[i].value;
          }
        }
        if (finalStops.isNotEmpty) {
          if (finalStops.first != 0.0) finalStops.first = 0.0;
          if (finalStops.last != 1.0) {
            if (finalStops.length > 1 && finalStops.last < finalStops[finalStops.length-2] + 0.00001){
              // 마지막 stop이 이전 stop과 너무 가까우면 이전 stop을 1.0으로
              finalStops[finalStops.length-2] = 1.0;
              finalColors.removeLast();
              finalStops.removeLast();
            } else {
              finalStops.last = 1.0;
            }
          }
        }
        gradientColors = finalColors;
        gradientStops = finalStops;
      }
    }

    if (gradientColors.length < 2 || gradientStops.length < 2 || gradientColors.length != gradientStops.length) {
      return Container(
        height: 12.0,
        width: totalBarWidth.isFinite && totalBarWidth > 0 ? totalBarWidth : null,
        color: activeSegments.isNotEmpty ? activeSegments.first['color'] : Colors.transparent,
      );
    }

    return Container(
      height: 12.0,
      width: totalBarWidth.isFinite && totalBarWidth > 0 ? totalBarWidth : null,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          stops: gradientStops,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    );
  }
}