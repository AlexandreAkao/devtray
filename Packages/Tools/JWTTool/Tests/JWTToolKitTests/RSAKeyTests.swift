import XCTest
@testable import JWTToolKit

final class RSAKeyTests: XCTestCase {
    let privatePEM = """
    -----BEGIN RSA PRIVATE KEY-----
    MIIEpAIBAAKCAQEAxn1VYQDbCUCE6Q9hiu3iIWNISRYAqePWPF6/jLhqt7cBuNIc
    k8G5yUaC4O0QTS+20HOmN84rKOj2VUey2o5KLWe2rNhD0Ul8tj/+JbWUrca7V9e2
    9AOAMT3RV6J07Pd74A2GR5a44xWRCmn95bOxoiNO+1FiLrzXfPGDu2JF0EmdycOP
    6jBXFt4Oedg3kesV4jtNw7OewFhZ98hPVjMfRDIEek3UkcdVxVysnkQyLqtYtLgD
    zZnHLQqqNMs6p9giKJisEhtnMSRVcNcfv1E9AJYKDKw1lZX5e88Vw8WwISnxOMAs
    x06Cy3lrJ7YibwhSeP4UNdmaouxaRCPLOmMIGwIDAQABAoIBAQDAwmTQ8IDGymaI
    40wKHJzXadCAUaLRWhbqx+Tj5xCUW2CLuVjRUXh4dEaT4wVKwEScyUMpvMmDUEIx
    bZDO2RJGaAsqblfl/qTjZOAOhPnfjTjQxQfCj0fGCk+r+HPu0ST24IuAKGpi9cXG
    REqy8UBXwkxomo9r7i6jAvS4XGaKL82MSCpk3v6LHvNL2fXUjuGxQSer9gHlYEwh
    IPsdreIboeSvWYXtmTHwi0y3dY9BssG14vnlvGdfKOA5ch1ZbOWr0Gw4MhtypJCK
    sTc4mizoP41x+njYKTWi/obdw/Yhz0vcRFah4tB0o0EzghUD85AjNAdetw1IfQcH
    4VnznwdZAoGBAOvIQYF56pkDnjo8rikjehEIPaWgInXUjf5D7fmGzF//5L9f36j3
    gr/u4z+L2+x7DRFYkczNRE/LQnoRhVUUOev7qcAbcL+JyITBj8aH88lg8mkNjwgI
    fPCODY1MS+uG/yXAUoS112C73iVi7Fujf+yQaBeMjq0Bj/sfI56TVmBlAoGBANeC
    c9GXyTrsWgIz4j9RBgEdP598ia7VliaN1WMDQ9m1GHGSrCg0CU5sNkGl42V4A/9R
    WcL6mMmONiDaCZZKajwkSwEeUC++4Y5odG9X/xgfUlK4YMDj0IiVgX2Kek2ozHHc
    9hDIv4ubzivn/H3j+Vw9ZlD1OWQW197gnq6sgf5/AoGBAJIbJtR32vL0tgD6hyXA
    8SxKwgC3SYNgspikOXxNlqnKZVJds7f9oE0VWEaRgTd6TO+5xad2b2VO3CPOZaQC
    A56C9X6wwl4+oD37v/9TUbMxWyXUHBTrRZi/PhCX/de2cLdRBRFtqUgtQoxCT5q9
    p1DNb2NgWy1D8Ze4hRcH0BetAoGAXHFI3Q8O8oeP1IIM+rv2p2O0duUk6ioUTlVo
    wyATar+TzKPt1RD9LPaeD2rpMA1bKZnrtwdnoo2uCkl880rYZxPqWIB4RQLMHhoQ
    V/KXKfHFjlYoqpUOTohTE1bjP4y4pd7ybiCuiWQ7+/l3BUlVHYv456FJDPX/g0s2
    xhaZbGECgYAUkchIDMtUpHqDpJutRaDHTd6YtGA5+9iLpGO4S5f8sa8jsD/nlFxZ
    RlfocBtsB+4mV/cqmN+/z6A8CgliyyWcFF+P5IjEPnhZjkf70CnITB7qzS0yrxd5
    lKr5ZnQWRHtFMiPtydBSl5f9Mu8OmHWxITnP/JzbvQlu+IB77GBACw==
    -----END RSA PRIVATE KEY-----
    """
    let publicPEM = """
    -----BEGIN RSA PUBLIC KEY-----
    MIIBCgKCAQEAxn1VYQDbCUCE6Q9hiu3iIWNISRYAqePWPF6/jLhqt7cBuNIck8G5
    yUaC4O0QTS+20HOmN84rKOj2VUey2o5KLWe2rNhD0Ul8tj/+JbWUrca7V9e29AOA
    MT3RV6J07Pd74A2GR5a44xWRCmn95bOxoiNO+1FiLrzXfPGDu2JF0EmdycOP6jBX
    Ft4Oedg3kesV4jtNw7OewFhZ98hPVjMfRDIEek3UkcdVxVysnkQyLqtYtLgDzZnH
    LQqqNMs6p9giKJisEhtnMSRVcNcfv1E9AJYKDKw1lZX5e88Vw8WwISnxOMAsx06C
    y3lrJ7YibwhSeP4UNdmaouxaRCPLOmMIGwIDAQAB
    -----END RSA PUBLIC KEY-----
    """

    func test_rs256_encode_then_verify_roundTrip() {
        let header = #"{"alg":"RS256","typ":"JWT"}"#
        let claims = #"{"sub":"99"}"#
        guard case .success(let token) = JWTEngine.encode(
            headerJSON: header, claimsJSON: claims, algorithm: .rs256, key: privatePEM) else {
            return XCTFail("RS256 encode failed")
        }
        XCTAssertEqual(try? JWTEngine.verify(token: token, algorithm: .rs256, key: publicPEM).get(), true)
    }

    func test_rs256_verify_tamperedPayload_false() {
        guard case .success(let token) = JWTEngine.encode(
            headerJSON: #"{"alg":"RS256"}"#, claimsJSON: #"{"a":1}"#, algorithm: .rs256, key: privatePEM) else {
            return XCTFail("encode failed")
        }
        var parts = token.split(separator: ".").map(String.init)
        parts[1] = "eyJhIjoyfQ" // {"a":2}
        let tampered = parts.joined(separator: ".")
        XCTAssertEqual(try? JWTEngine.verify(token: tampered, algorithm: .rs256, key: publicPEM).get(), false)
    }

    func test_rs256_malformedPEM_fails() {
        if case .success = JWTEngine.verify(token: "a.b.c", algorithm: .rs256, key: "not a pem") {
            XCTFail("expected failure on malformed PEM")
        }
    }
}
