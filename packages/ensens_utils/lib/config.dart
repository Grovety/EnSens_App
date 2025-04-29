class EnsensBleConfig {
  final String prefixDeviceSensor = 'ES_';
  final String uuidBattery = '2a19';
  final String uuidServiceIndicators = '181a';
  final String uuidTemperature = '2a6e';
  final String uuidCo2 = '2b8c';
  final String uuidPressure = '2a6d';
  final String uuidVoc = '2be7';
  final String uuidHumidity = '2a6f';
  final String uuidIaq = 'e2890598-1286-43d6-82ba-121248bda7da';
  final String uuidCurrentTime = '2a2b';
  final String uuidHistoryRead = 'e3890598-1286-43d6-82ba-121248bda7da';
  final String uuidHistoryWrite = 'e4890598-1286-43d6-82ba-121248bda7da';

  final int historyBytesLen = 20;
}

class PressureParams {
  final int lowX = -24;
  final int intervalX = 24;
  final int highX = 24;

  final int lowHpa = 900;
  final int highHpa = 1100;

  final int lowMmHg = 710;
  final int highMmHg = 790;
}

class EnsensConfig {
  final int kHistoryMaxLenDays = 1; // today and yesterday
  final int kHistoryUpdateMinutes = 15;
  final int kPreviousLiveDataMinutes = 5;

  final PressureParams pressure = PressureParams();
}
