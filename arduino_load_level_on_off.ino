// Define the EEPROM size and the LED pin
#define EEPROM_SIZE 1024
#define LED_PIN 13

// Declare a global variable to store the cycle count
uint32_t cycle_count;

// A function to read a 32-bit unsigned integer from a given EEPROM address
uint32_t read_uint32(int address) {
  uint32_t value = 0;
  for (int i = 0; i < 4; i++) {
    value = (value << 8) + EEPROM.read(address + i);
  }
  return value;
}

// A function to write a 32-bit unsigned integer to a given EEPROM address
void write_uint32(int address, uint32_t value) {
  for (int i = 0; i < 4; i++) {
    EEPROM.write(address + i, (value >> (8 * (3 - i))) & 0xFF);
  }
}

// A function to find the highest cycle count stored in the EEPROM
uint32_t find_max_cycle_count() {
  uint32_t max_count = 0;
  for (int i = 0; i < EEPROM_SIZE; i += 4) {
    uint32_t count = read_uint32(i);
    if (count > max_count) {
      max_count = count;
    }
  }
  return max_count;
}

// A function to write the incremented cycle count to a random EEPROM address
void write_new_cycle_count() {
  // Increment the cycle count by one
  cycle_count++;

  // Generate a random address that is a multiple of 4 and within the EEPROM size
  int address = random(0, EEPROM_SIZE / 4) * 4;

  // Write the cycle count to the EEPROM address
  write_uint32(address, cycle_count);
}

void setup() {
  // Initialize the serial communication
  Serial.begin(9600);

  // Initialize the LED pin as output
  pinMode(LED_PIN, OUTPUT);

  // Read the highest cycle count from the EEPROM
  cycle_count = find_max_cycle_count();

  // Write the new cycle count to a random EEPROM address
  write_new_cycle_count();

  // Print the cycle count to the serial monitor
  Serial.println(cycle_count);

  // Turn on the LED
  digitalWrite(LED_PIN, HIGH);
}

void loop() {
  // Do nothing
}
