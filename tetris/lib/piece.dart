import 'dart:ui';

import 'package:tetris/board.dart';
import 'package:tetris/values.dart';

class Piece {
  // Type of tetris pieces
  Tetromino type;

  Piece({required this.type});

  // The pieces are just list of integers
  List<int> position = [];

  // Color of tetris pieces
  Color get color {
    return tetrominoColors[type] ?? const Color(0xFFFFFFFF);
  }

  // Generate the integers
  void initializePiece() {
    switch (type) {
      case Tetromino.L:
        position = [
          -26,
          -16,
          -6,
          -5,
        ];
        break;
      case Tetromino.J:
        position = [
          -25,
          -15,
          -5,
          -6,
        ];
        break;
      case Tetromino.I:
        position = [
          -4,
          -5,
          -6,
          -7,
        ];
        break;
      case Tetromino.O:
        position = [
          -15,
          -16,
          -5,
          -6,
        ];
        break;
      case Tetromino.S:
        position = [
          -15,
          -14,
          -5,
          -6,
        ];
        break;
      case Tetromino.Z:
        position = [
          -17,
          -16,
          -6,
          -5,
        ];
        break;
      case Tetromino.T:
        position = [
          -26,
          -16,
          -6,
          -15,
        ];
        break;
      default:
    }
  }

  // Move Piece
  void movePiece(Direction direction) {
    switch (direction) {
      case Direction.down:
        for (int i = 0; i < position.length; i++) {
          position[i] += rowLength;
        }
        break;
      case Direction.left:
        for (int i = 0; i < position.length; i++) {
          position[i] -= 1;
        }
        break;
      case Direction.right:
        for (int i = 0; i < position.length; i++) {
          position[i] += 1;
        }
        break;
      default:
    }
  }

  // Rotate Piece
  int rotationState = 1;

  // Return a list of possible rotated positions (with simple horizontal kicks).
  List<List<int>> getRotatedCandidates() {
    // O tetromino doesn't rotate — only current position is a valid candidate
    if (type == Tetromino.O) return [List<int>.from(position)];

    // choose pivot (use second cell if available)
    final int pivot = position.isNotEmpty
        ? (position.length > 1 ? position[1] : position[0])
        : 0;
    final int pivotRow = (pivot / rowLength).floor();
    final int pivotCol = pivot - pivotRow * rowLength;

    // build rotated positions around pivot (90° clockwise)
    List<int> rotated = [];
    List<int> rotatedCols = [];
    List<int> rotatedRows = [];
    for (var p in position) {
      final int row = (p / rowLength).floor();
      final int col = p - row * rowLength;
      final int relR = row - pivotRow;
      final int relC = col - pivotCol;

      // rotate: (relR, relC) -> (-relC, relR)
      final int newR = pivotRow + (-relC);
      final int newC = pivotCol + (relR);
      rotatedRows.add(newR);
      rotatedCols.add(newC);
      rotated.add(newR * rowLength + newC);
    }

    // produce candidates by shifting columns (avoid index-wrapping)
    final List<int> kicks = [0, -1, 1, -2, 2];
    List<List<int>> candidates = [];

    for (final shift in kicks) {
      final List<int> candidate = <int>[];
      bool outOfColRange = false;
      for (int i = 0; i < rotatedRows.length; i++) {
        final int r = rotatedRows[i];
        final int c = rotatedCols[i] + shift;
        // if column is out of range, mark and skip this kick
        if (c < 0 || c >= rowLength) {
          outOfColRange = true;
          break;
        }
        candidate.add(r * rowLength + c);
      }
      if (!outOfColRange) {
        candidates.add(candidate);
      }
    }

    // ensure candidates are ordered by smallest horizontal shift first
    candidates.sort((a, b) {
      // compute average column shift relative to original rotated columns
      int avgShift(List<int> cand) {
        int sum = 0;
        for (int i = 0; i < cand.length; i++) {
          final int r = (cand[i] / rowLength).floor();
          final int c = cand[i] - r * rowLength;
          sum += (c - rotatedCols[i]).abs();
        }
        return sum;
      }

      return avgShift(a).compareTo(avgShift(b));
    });

    return candidates;
  }

  // Check if valid position (within bounds)
  bool positionIsValid(int pos) {
    // Get the row and column of the position using floor division
    final int row = (pos / rowLength).floor();
    final int col = pos - row * rowLength; // can be negative or >= rowLength

    // Column must be inside board
    if (col < 0 || col >= rowLength) return false;

    // If the position is inside visible board, ensure it's not occupied
    if (row >= 0 && row < colLength && gameBoard[row][col] != null) {
      return false;
    }

    // valid (rows < 0 are allowed as spawn)
    return true;
  }

  // Check if piece is in valid position
  bool pieceIsInValidPosition(List<int> piecePosition) {
    bool firstColOccupied = false;
    bool lastColOccupied = false;

    for (final pos in piecePosition) {
      // Return false if any position is invalid
      if (!positionIsValid(pos)) return false;

      // compute column without modulo to avoid wrapping
      final int row = (pos / rowLength).floor();
      final int col = pos - row * rowLength;

      // Check if first or last column is occupied
      if (col == 0) firstColOccupied = true;
      if (col == rowLength - 1) lastColOccupied = true;
    }

    // If there is a piece in both first and last col, it would be going through walls
    return !(firstColOccupied && lastColOccupied);
  }
}
