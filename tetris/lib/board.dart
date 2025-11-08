import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:tetris/piece.dart';
import 'package:tetris/pixel.dart';
import 'package:tetris/values.dart';
import 'package:url_launcher/url_launcher.dart';

// Create the game board as a 2D list
List<List<Tetromino?>> gameBoard = List.generate(
  colLength,
  (i) => List<Tetromino?>.generate(
    rowLength,
    (j) => null,
  ),
);

class GameBoard extends StatefulWidget {
  const GameBoard({super.key});

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  // Current tetris piece
  Piece currentPiece = Piece(type: Tetromino.L);

  // Current score
  int currentScore = 0;

  // Game over state: tracks
  bool gameOver = false;

  // whether the game has started (controls overlay visibility)
  bool isPlaying = false;

  get onTap => null;

  // Hard drop: move piece down until it collides, then lock it
  void hardDrop() {
    // move down until collision
    while (!checkCollision(Direction.down)) {
      currentPiece.movePiece(Direction.down);
    }

    // Now it should be right above collision — lock it
    setState(() {
      checkLanding(); // will mark board and create new piece
    });
  }

  @override
  void initState() {
    super.initState();

    // prepare the first piece but do NOT start the game loop yet;
    // user will tap the board to start
    currentPiece.initializePiece();
  }

  void startGame() {
    // ensure the current piece is initialized (safe to call again)
    currentPiece.initializePiece();

    // mark as playing
    setState(() => isPlaying = true);

    // Frame refresh rate
    Duration frameRate = const Duration(milliseconds: 800);
    gameLoop(frameRate);
  }

  // Game Loop
  void gameLoop(Duration frameRate) {
    Timer.periodic(frameRate, (timer) {
      setState(() {
        // Clear lines if any
        clearLines();

        // Check for game over
        if (gameOver == true) {
          timer.cancel();
          showGameOverDialog();
        }
        // Check if piece has landed
        checkLanding();
        // Move current piece down
        currentPiece.movePiece(Direction.down);
      });
    });
  }

  void showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Game Over !'),
          content: Text('Your final score is: $currentScore'),
          actions: <Widget>[
            TextButton(
              child: const Text('Play Again'),
              onPressed: () {
                // Reset the game state
                setState(() {
                  // Clear the game board
                  for (int i = 0; i < colLength; i++) {
                    for (int j = 0; j < rowLength; j++) {
                      gameBoard[i][j] = null;
                    }
                  }
                  currentScore = 0;
                  gameOver = false;
                  isPlaying = false;
                  createNewPiece();
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Check for collision in a future position
  // returns true if there is a collision
  // false otherwise
  bool checkCollision(Direction direction) {
    for (int i = 0; i < currentPiece.position.length; i++) {
      int pos = currentPiece.position[i];

      // Handle vertical movement
      if (direction == Direction.down) {
        int newIndex = pos + rowLength;

        // if the new index is still above the board, ignore this cell
        if (newIndex < 0) continue;

        int newRow = newIndex ~/ rowLength;
        int newCol = newIndex % rowLength;

        // collision with bottom boundary
        if (newRow >= colLength) return true;

        // collision with landed pieces
        if (gameBoard[newRow][newCol] != null) return true;
      } else {
        // Horizontal movement (left / right)
        // If the cell is above the board, allow horizontal move (don't block)
        if (pos < 0) continue;

        int row = pos ~/ rowLength;
        int col = pos % rowLength;
        int newCol = (direction == Direction.right) ? col + 1 : col - 1;

        // collision with left/right boundaries
        if (newCol < 0 || newCol >= rowLength) return true;

        // collision with landed pieces
        if (gameBoard[row][newCol] != null) return true;
      }
    }

    return false;
  }

  void checkLanding() {
    if (checkCollision(Direction.down)) {
      // Mark positions on the game board as occupied
      for (int i = 0; i < currentPiece.position.length; i++) {
        int row = (currentPiece.position[i] / rowLength).floor();
        int col = currentPiece.position[i] % rowLength;

        // ensure indices are inside the board before marking
        if (row >= 0 && row < colLength && col >= 0 && col < rowLength) {
          gameBoard[row][col] = currentPiece.type;
        }
      }

      // Create a new piece
      createNewPiece();
    }
  }

  void createNewPiece() {
    // Create a random object to genarate random tetromino types
    Random rand = Random();

    // Create a new piece with a random tetromino type
    Tetromino randomType =
        Tetromino.values[rand.nextInt(Tetromino.values.length)];
    currentPiece = Piece(type: randomType);
    currentPiece.initializePiece();

    if (isGameOver()) {
      gameOver = true;
    }
  }

  // Move piece left
  void moveLeft() {
    // Make sure the move is valid before moving there
    if (!checkCollision(Direction.left)) {
      setState(() {
        currentPiece.movePiece(Direction.left);
      });
    }
  }

  // Move piece right
  void moveRight() {
    // Make sure the move is valid before moving there
    if (!checkCollision(Direction.right)) {
      setState(() {
        currentPiece.movePiece(Direction.right);
      });
    }
  }

  // Rotate piece (try wall-kicks and validate against board)
  void rotatePiece() {
    final oldPos = List<int>.from(currentPiece.position);
    final oldState = currentPiece.rotationState;

    final candidates = currentPiece.getRotatedCandidates();

    for (final candidate in candidates) {
      bool invalid = false;

      for (final p in candidate) {
        final int row = (p / rowLength).floor();
        final int col = p % rowLength;

        // column must be inside board
        if (col < 0 || col >= rowLength) {
          invalid = true;
          break;
        }

        // row >= 0 means inside visible board — check for collisions with landed pieces
        if (row >= 0 && row < colLength && gameBoard[row][col] != null) {
          invalid = true;
          break;
        }
      }

      if (!invalid) {
        // apply candidate and update rotation state
        setState(() {
          currentPiece.position = candidate;
          currentPiece.rotationState = (currentPiece.rotationState + 1) % 4;
        });
        return;
      }
    }

    // none of the candidates were valid -> keep old position/state
    currentPiece.position = oldPos;
    currentPiece.rotationState = oldState;
  }

  // Clear Lines
  void clearLines() {
    // Step 1: Loop through each row from bottom to top
    for (int row = colLength - 1; row >= 0; row--) {
      // Step 2: Initialize a flag to check if the row is full
      bool rowIsFull = true;

      // Step 3: Check if the row is full (All columns occupied)
      for (int col = 0; col < rowLength; col++) {
        if (gameBoard[row][col] == null) {
          rowIsFull = false;
          break;
        }
      }

      // Step 4: If the row is full, clear it and move everything above it down
      if (rowIsFull) {
        // Step 5: Move all rows above down by one
        for (int r = row; r > 0; r--) {
          // Copy the row above to the current row
          gameBoard[r] = List.from(gameBoard[r - 1]);
        }

        // Step 6: Set the top row to empty
        gameBoard[0] = List.generate(row, (index) => null);

        // Step 7: Increase the score
        currentScore++;
      }
    }
  }

  // Game Over Method
  bool isGameOver() {
    // Check if any cell in the top row is occupied
    for (int col = 0; col < rowLength; col++) {
      if (gameBoard[0][col] != null) {
        return true; // Game over condition met
      }
    }
    return false; // Game is still ongoing
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        // Game Board Grid
        children: [
          // Use a Stack so we can overlay the "Tap to play" message on top of the board
          Expanded(
            child: Stack(
              children: [
                GridView.builder(
                  itemCount: rowLength * colLength,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: rowLength),
                  itemBuilder: (context, index) {
                    // Get row and column of each index
                    int row = (index / rowLength).floor();
                    int col = index % rowLength;

                    // Current piece
                    if (currentPiece.position.contains(index)) {
                      return Pixel(
                        color: currentPiece.color,
                      );
                    }

                    // Landed pieces
                    else if (gameBoard[row][col] != null) {
                      final Tetromino? tetrominoType = gameBoard[row][col];
                      return Pixel(color: tetrominoColors[tetrominoType]);
                    }
                    // Blank pixel
                    else {
                      return Pixel(
                        color: Colors.grey[900],
                      );
                    }
                  },
                ),

                // Tap-to-play overlay (visible only when not playing)
                if (!isPlaying)
                  Positioned.fill(
                    child: Material(
                      color: Colors.black54,
                      child: InkWell(
                        onTap: () {
                          // start the game and hide the overlay
                          startGame();
                        },
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white30),
                            ),
                            child: const Text(
                              'Tap to play',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Score display (plain text, no border)
          // Score Display
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 15.0),
                  child: Text(
                    'Score: $currentScore',
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Left Button
                      ControlButton(
                        icon: Icons.arrow_back_ios,
                        onPressed: moveLeft,
                        size: 50,
                        borderColor: Colors.white30,
                      ),

                      // Rotate Button
                      ControlButton(
                        icon: Icons.rotate_right,
                        onPressed: rotatePiece,
                        size: 50,
                        borderColor: Colors.white30,
                      ),

                      // Down (Hard Drop) Button
                      ControlButton(
                        icon: Icons.arrow_downward,
                        onPressed: hardDrop,
                        size: 50,
                        borderColor: Colors.white30,
                      ),

                      // Right Button
                      ControlButton(
                        icon: Icons.arrow_forward_ios,
                        onPressed: moveRight,
                        size: 50,
                        borderColor: Colors.white30,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Small footer area
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  Text(
                    '© 2025 • Made by',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  TextButton(
                    onPressed: _launchProfile,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'SK Miraj Ahamed',
                      style: TextStyle(
                        color: Colors.white,
                        decoration: TextDecoration.underline,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Add this widget anywhere above _GameBoardState (or below - it's fine in this file)
class ControlButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final Color borderColor;
  final double borderRadius;
  final Color iconColor;
  final Color backgroundColor;
  final Offset iconOffset; // <--- added

  const ControlButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 56,
    this.borderColor = Colors.transparent,
    this.borderRadius = 8,
    this.iconColor = Colors.white,
    this.backgroundColor = Colors.transparent,
    this.iconOffset = Offset.zero, // <--- added
  });

  @override
  State<ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<ControlButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.94 : 1.0,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      child: Material(
        color: widget.backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          onTap: widget.onPressed,
          onHighlightChanged: (value) {
            setState(() => _pressed = value);
          },
          splashColor: Colors.white24,
          child: Container(
            width: widget.size,
            height: widget.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(color: widget.borderColor),
              color: Colors.transparent,
            ),
            // apply offset to icon for fine tuning
            child: Transform.translate(
              offset: widget.iconOffset,
              child: Icon(widget.icon, color: widget.iconColor),
            ),
          ),
        ),
      ),
    );
  }
}

_launchProfile() async {
  const url = 'https://miraj-since2005.github.io/Miraj_Portfolio/';
  // ignore: deprecated_member_use
  if (await canLaunch(url)) {
    // ignore: deprecated_member_use
    await launch(url);
  } else {
    throw 'Could not launch $url';
  }
}
