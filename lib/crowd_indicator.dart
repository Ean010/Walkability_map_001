import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class CrowdIndicator extends StatelessWidget {
  final int level;
  final String name;
  final Key? key;
  
  const CrowdIndicator({this.key, required this.level, required this.name});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: _getColorForLevel(level),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _getColorForLevel(level),
            blurRadius: 20,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: _getColorForLevel(level).withOpacity(0.8),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              level.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Color _getColorForLevel(int level) {
    final validLevel = level.clamp(1, 5);
    return [
      Colors.green.withOpacity(0.4),
      Colors.lightGreen.withOpacity(0.4),
      Colors.yellow.withOpacity(0.5),
      Colors.orange.withOpacity(0.6),
      Colors.red.withOpacity(0.7),
    ][validLevel - 1];
  }
}

// Alternative approach: Create a custom heatmap circle widget
class HeatmapCircle extends StatelessWidget {
  final int level;
  final String name;
  final double radius;
  final Key? key;
  
  const HeatmapCircle({
    this.key, 
    required this.level, 
    required this.name,
    this.radius = 30,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Show tooltip or info dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name - Crowd level: $level/5'),
            duration: const Duration(seconds: 2),
            backgroundColor: _getColorForLevel(level),
          ),
        );
      },
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              _getColorForLevel(level),
              _getColorForLevel(level).withOpacity(0.1),
            ],
            stops: const [0.3, 1.0],
          ),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: _getColorForLevel(level),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Color _getColorForLevel(int level) {
    final validLevel = level.clamp(1, 5);
    return [
      const Color(0xFF4CAF50), // Green
      const Color(0xFF8BC34A), // Light Green
      const Color(0xFFFFEB3B), // Yellow
      const Color(0xFFFF9800), // Orange
      const Color(0xFFF44336), // Red
    ][validLevel - 1];
  }
}