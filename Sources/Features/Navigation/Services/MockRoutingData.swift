import Foundation

struct MockRoutingData {
    static let tomTomResponseJSON = """
    {
      "formatVersion": "0.0.12",
      "routes": [
        {
          "summary": {
            "lengthInMeters": 2100,
            "travelTimeInSeconds": 450
          },
          "legs": [
            {
              "summary": {
                "lengthInMeters": 2100,
                "travelTimeInSeconds": 450
              },
              "points": [
                {"latitude": 37.77490, "longitude": -122.41940},
                {"latitude": 37.77550, "longitude": -122.41800},
                {"latitude": 37.77650, "longitude": -122.41600},
                {"latitude": 37.77750, "longitude": -122.41400},
                {"latitude": 37.77850, "longitude": -122.41200},
                {"latitude": 37.77950, "longitude": -122.41000},
                {"latitude": 37.78050, "longitude": -122.40800},
                {"latitude": 37.78150, "longitude": -122.40600},
                {"latitude": 37.78200, "longitude": -122.40500},
                {"latitude": 37.78250, "longitude": -122.40400},
                {"latitude": 37.78300, "longitude": -122.40300},
                {"latitude": 37.78350, "longitude": -122.40200},
                {"latitude": 37.78400, "longitude": -122.40000},
                {"latitude": 37.78450, "longitude": -122.39800},
                {"latitude": 37.78480, "longitude": -122.39750},
                {"latitude": 37.78500, "longitude": -122.39700},
                {"latitude": 37.78600, "longitude": -122.39600},
                {"latitude": 37.78700, "longitude": -122.39500},
                {"latitude": 37.78800, "longitude": -122.39400},
                {"latitude": 37.78900, "longitude": -122.39300},
                {"latitude": 37.79000, "longitude": -122.39200},
                {"latitude": 37.79100, "longitude": -122.39100}
              ]
            }
          ],
          "guidance": {
            "instructions": [
              {
                "routeOffsetInMeters": 0,
                "travelTimeInSeconds": 0,
                "pointIndex": 0,
                "instructionType": "START",
                "street": "Market St",
                "message": "Head northeast on Market St"
              },
              {
                "routeOffsetInMeters": 800,
                "travelTimeInSeconds": 150,
                "pointIndex": 7,
                "instructionType": "TURN_RIGHT",
                "street": "3rd St",
                "message": "At the traffic signal, turn right onto 3rd St"
              },
              {
                "routeOffsetInMeters": 1400,
                "travelTimeInSeconds": 260,
                "pointIndex": 12,
                "instructionType": "MOTORWAY_ENTER",
                "street": "I-80 East",
                "message": "Get on I-80 East"
              },
              {
                "routeOffsetInMeters": 1800,
                "travelTimeInSeconds": 350,
                "pointIndex": 16,
                "instructionType": "TURN_LEFT",
                "street": "Howard St",
                "message": "At the stop sign, turn left onto Howard St"
              },
              {
                "routeOffsetInMeters": 2100,
                "travelTimeInSeconds": 450,
                "pointIndex": 21,
                "instructionType": "ARRIVE",
                "street": "",
                "message": "You have reached your destination"
              }
            ]
          }
        },
        {
          "summary": {
            "lengthInMeters": 2400,
            "travelTimeInSeconds": 540
          },
          "tags": ["zero_cameras"],
          "legs": [
            {
              "summary": {
                "lengthInMeters": 2400,
                "travelTimeInSeconds": 540
              },
              "points": [
                {"latitude": 37.77490, "longitude": -122.41940},
                {"latitude": 37.77600, "longitude": -122.42000},
                {"latitude": 37.77800, "longitude": -122.41900},
                {"latitude": 37.78000, "longitude": -122.41800},
                {"latitude": 37.78200, "longitude": -122.41500},
                {"latitude": 37.78400, "longitude": -122.41000},
                {"latitude": 37.78600, "longitude": -122.40500},
                {"latitude": 37.78800, "longitude": -122.40000},
                {"latitude": 37.79000, "longitude": -122.39500},
                {"latitude": 37.79100, "longitude": -122.39100}
              ]
            }
          ],
          "guidance": {
            "instructions": [
              {
                "routeOffsetInMeters": 0,
                "travelTimeInSeconds": 0,
                "pointIndex": 0,
                "instructionType": "START",
                "street": "Market St",
                "message": "Head northwest on Market St"
              },
              {
                "routeOffsetInMeters": 500,
                "travelTimeInSeconds": 100,
                "pointIndex": 2,
                "instructionType": "TURN_RIGHT",
                "street": "Van Ness Ave",
                "message": "Turn right onto Van Ness Ave"
              },
              {
                "routeOffsetInMeters": 1500,
                "travelTimeInSeconds": 300,
                "pointIndex": 5,
                "instructionType": "TURN_RIGHT",
                "street": "Pine St",
                "message": "Turn right onto Pine St"
              },
              {
                "routeOffsetInMeters": 2400,
                "travelTimeInSeconds": 540,
                "pointIndex": 9,
                "instructionType": "ARRIVE",
                "street": "",
                "message": "You have reached your destination"
              }
            ]
          }
        },
        {
          "summary": {
            "lengthInMeters": 2800,
            "travelTimeInSeconds": 600
          },
          "tags": ["less_traffic"],
          "legs": [
            {
              "summary": {
                "lengthInMeters": 2800,
                "travelTimeInSeconds": 600
              },
              "points": [
                {"latitude": 37.77490, "longitude": -122.41940},
                {"latitude": 37.77300, "longitude": -122.41700},
                {"latitude": 37.77200, "longitude": -122.41400},
                {"latitude": 37.77400, "longitude": -122.41000},
                {"latitude": 37.77600, "longitude": -122.40600},
                {"latitude": 37.77800, "longitude": -122.40200},
                {"latitude": 37.78000, "longitude": -122.39800},
                {"latitude": 37.78400, "longitude": -122.39400},
                {"latitude": 37.78800, "longitude": -122.39000},
                {"latitude": 37.79100, "longitude": -122.39100}
              ]
            }
          ],
          "guidance": {
            "instructions": [
              {
                "routeOffsetInMeters": 0,
                "travelTimeInSeconds": 0,
                "pointIndex": 0,
                "instructionType": "START",
                "street": "Market St",
                "message": "Head southeast on Market St"
              },
              {
                "routeOffsetInMeters": 600,
                "travelTimeInSeconds": 120,
                "pointIndex": 2,
                "instructionType": "TURN_LEFT",
                "street": "8th St",
                "message": "Turn left onto 8th St"
              },
              {
                "routeOffsetInMeters": 1800,
                "travelTimeInSeconds": 360,
                "pointIndex": 6,
                "instructionType": "TURN_LEFT",
                "street": "Harrison St",
                "message": "Turn left onto Harrison St"
              },
              {
                "routeOffsetInMeters": 2800,
                "travelTimeInSeconds": 600,
                "pointIndex": 9,
                "instructionType": "ARRIVE",
                "street": "",
                "message": "You have reached your destination"
              }
            ]
          }
        }
      ]
    }
    """
}
