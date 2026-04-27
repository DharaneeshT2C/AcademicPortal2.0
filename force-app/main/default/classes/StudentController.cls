public with sharing class StudentController {
    @AuraEnabled(cacheable=true)
    public static Contact getStudentContact() {

        User u = [
            SELECT ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        if (u.ContactId == null) {
            return null;
        }

        return [
            SELECT Id, Name
            FROM Contact
            WHERE Id = :u.ContactId
            LIMIT 1
        ];
    }
}