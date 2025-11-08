// Grid Dimensions
import 'dart:ui';

int rowLength = 10;
int colLength = 15;

enum Direction {
  left,
  right,
  down,
}

enum Tetromino {
  L,
  J,
  I,
  O,
  S,
  Z,
  T,
}

// Colors for each Tetromino
const Map<Tetromino, Color> tetrominoColors = {
  Tetromino.L: Color(0xFFFFA500), // Orange
  Tetromino.J: Color(0xFF0000FF), // Blue
  Tetromino.I: Color(0xFF00FFFF), // Cyan
  Tetromino.O: Color(0xFFFFFF00), // Yellow
  Tetromino.S: Color(0xFF00FF00), // Green
  Tetromino.Z: Color(0xFFFF0000), // Red
  Tetromino.T: Color(0xFF800080), // Purple
};
