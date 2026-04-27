public without sharing class RazorpayCrypto {
    // Returns lowercase hex string of HMAC SHA256
    public static String hmacSha256Hex(String payload, String secret) {
        Blob mac = Crypto.generateMac('HmacSHA256', Blob.valueOf(payload), Blob.valueOf(secret));
        return EncodingUtil.convertToHex(mac).toLowerCase();
    }

    public static Boolean safeEquals(String a, String b) {
        if (a == null || b == null) return false;
        if (a.length() != b.length()) return false;
        Integer diff = 0;
        for (Integer i = 0; i < a.length(); i++) {
            diff |= (a.substring(i, i+1).charAt(0) ^ b.substring(i, i+1).charAt(0));
        }
        return diff == 0;
    }
}