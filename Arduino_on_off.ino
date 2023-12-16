// Define the EEPROM address to store the cycle count
#define EEPROM_ADDR 0

// Define the LED pin
#define LED_PIN 13

// Define the variable to store the cycle count
uint32_t cycle_count;

void setup() {
  // Initialize serial communication
  Serial.begin(9600);

  // Read the cycle count from EEPROM
  cycle_count = EEPROM.readLong(EEPROM_ADDR);

  // Increment the cycle count by one
  cycle_count++;

  // Write the cycle count back to EEPROM
  EEPROM.writeLong(EEPROM_ADDR, cycle_count);

  // Print the cycle count to serial monitor
  Serial.print("Cycle count: ");
  Serial.println(cycle_count);

  // Turn on the LED
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, HIGH);
}

void loop() {
  // Do nothing, wait forever
}
