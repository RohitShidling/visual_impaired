# Hotword Detection - Google-Like Implementation

This app uses an efficient two-stage approach for "Hey Surya" hotword detection, similar to how Google Assistant works with "Hey Google".

## How It Works

### Two-Stage Processing

1. **Stage 1: Hotword Detection**
   - The app listens for the "Hey Surya" trigger phrase
   - Uses short, efficient listening cycles to conserve battery
   - Takes periodic breaks between listening sessions

2. **Stage 2: Command Processing**
   - Once "Hey Surya" is detected, enters command mode
   - Processes the command that follows the hotword
   - Can handle commands in the same utterance (e.g., "Hey Surya detect objects")
   - Or waits for a follow-up command if only the hotword was detected

### Efficient Battery Usage

The system implements several strategies to minimize battery consumption:

1. **Active-Pause Cycles**
   - Short active listening periods (5 seconds)
   - Brief pauses between cycles (2 seconds)
   - Reduces continuous CPU and microphone usage

2. **Adaptive Breaks**
   - Takes longer breaks after extended listening periods
   - Automatically restarts listening after breaks
   - Prevents excessive battery drain during long-term use

3. **Smart Processing**
   - Processes commands in the same utterance as the hotword when possible
   - Reduces the need for multiple listening cycles

## Advantages

- No external API keys required
- No custom model files needed
- Works across all supported platforms
- Mimics Google Assistant's efficient approach
- Balances responsiveness with battery efficiency

## Usage Tips

For best results:
- Speak clearly when saying "Hey Surya"
- You can combine "Hey Surya" with your command in one sentence
- For complex commands, wait for the acknowledgment after saying "Hey Surya"

## Note

The continuous listening approach may use more battery than specialized hotword detection libraries, but it provides a good balance between functionality and simplicity. 