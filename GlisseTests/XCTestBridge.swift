import XCTest

final class TrackFilterTests: XCTestCase {
    func testRejectsPoorAccuracy() throws { try LogicChecks.rejectsBadAccuracy() }
    func testRejectsNonFinite() throws { try LogicChecks.rejectsNonFinite() }
    func testRejectsTimeRegression() throws { try LogicChecks.rejectsTimeRegression() }
    func testRejectsSpeedSpike() throws { try LogicChecks.rejectsSpeedSpikeWithoutAddingDistance() }
    func testJitterDoesNotInflateDistance() throws { try LogicChecks.jitterDoesNotInflateDistance() }
    func testGapDoesNotDrawStraightLine() throws { try LogicChecks.gapDoesNotDrawStraightLine() }
}

final class RunDetectorTests: XCTestCase {
    func testCleanDescentIsOneRun() throws { try LogicChecks.cleanDescentIsOneRun() }
    func testDescentLiftDescentIsTwoRuns() throws { try LogicChecks.descentLiftDescentIsTwoRuns() }
    func testLiftAloneIsNotARun() throws { try LogicChecks.liftAloneIsNotARun() }
    func testShortBurstIsNotQualified() throws { try LogicChecks.shortBurstIsNotAQualifiedRun() }
    func testStationaryIsRest() throws { try LogicChecks.stationaryIsRest() }
    func testReplayMatchesIncremental() throws { try LogicChecks.replayMatchesIncremental() }
    func testNoisyDescentStillOneRun() throws { try LogicChecks.noisyDescentStillOneRun() }
    func testSampleDayHasSeveralRuns() throws { try LogicChecks.sampleDayHasSeveralRuns() }
}

final class AirtimeTests: XCTestCase {
    func testCountsArmedJump() throws { try LogicChecks.airtimeCountsArmedJump() }
    func testIgnoresTinyLongAndUnarmed() throws { try LogicChecks.airtimeIgnoresTinyAndLongAndUnarmed() }
}

final class GPXAndUnitsTests: XCTestCase {
    func testHaversine() throws {
        try LogicChecks.haversineLatitudeDegree()
        try LogicChecks.haversineZero()
        try LogicChecks.projectRoundTrip()
    }

    func testGPXRoundTrip() throws { try LogicChecks.gpxRoundTripCoordinates() }
    func testSessionFileRoundTrip() throws { try LogicChecks.sessionFileRoundTrip() }
    func testSeasonBoundaries() throws { try LogicChecks.seasonBoundaries() }
    func testSpeedBands() throws { try LogicChecks.speedBands() }
    func testFormats() throws { try LogicChecks.durationAndDecimalFormat() }
}
