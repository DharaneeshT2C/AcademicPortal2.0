/**
 * ************************************************************************************************
 * @className  KenHostelDetailsController
 *
 * @description
 *  Backs the `my/hostelDetails` LWC page — room info, roommate, facilities list.
 *
 *  TODO[SOBJECT]: Wire to `Hostel_Allocation__c` (Student__c, Room__c, Wing__c,
 *                 Roommate__c, Check_In_Date__c).
 * ************************************************************************************************
 */
public without sharing class KenHostelDetailsController {

    public class FacilityDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String icon;
        @AuraEnabled public String label;
        @AuraEnabled public Boolean available;
    }

    public class HostelDTO {
        @AuraEnabled public String            roomNumber;
        @AuraEnabled public String            block;
        @AuraEnabled public String            floor;
        @AuraEnabled public String            type;       // 'Single' | 'Shared' | 'Triple'
        @AuraEnabled public String            roommateName;
        @AuraEnabled public String            wardenName;
        @AuraEnabled public String            wardenPhone;
        @AuraEnabled public String            checkInDate;
        @AuraEnabled public String            checkOutDate;
        @AuraEnabled public List<FacilityDTO> facilities;
    }

    @AuraEnabled(cacheable=true)
    public static HostelDTO getHostelDetails() {
        try {
            HostelDTO h = new HostelDTO();
            h.facilities = new List<FacilityDTO>();
            Id contactId = KenRunningStudentHelper.optionalContactId();
            if (contactId != null) {
                List<Hostel_Allocation__c> rows = [
                    SELECT Id, Room_Number__c, Block__c, Floor__c, Type__c,
                           Roommate_Name__c, Warden_Name__c, Warden_Phone__c,
                           Check_In_Date__c, Check_Out_Date__c
                    FROM Hostel_Allocation__c
                    WHERE Student__c = :contactId
                    WITH SECURITY_ENFORCED
                    LIMIT 1
                ];
                if (!rows.isEmpty()) {
                    Hostel_Allocation__c r = rows[0];
                    h.roomNumber   = r.Room_Number__c;
                    h.block        = r.Block__c;
                    h.floor        = r.Floor__c;
                    h.type         = r.Type__c;
                    h.roommateName = r.Roommate_Name__c;
                    h.wardenName   = r.Warden_Name__c;
                    h.wardenPhone  = r.Warden_Phone__c;
                    h.checkInDate  = r.Check_In_Date__c == null ? '' : r.Check_In_Date__c.format();
                    h.checkOutDate = r.Check_Out_Date__c == null ? '' : r.Check_Out_Date__c.format();
                    return h;
                }
            }
            // No allocation found — return null core fields, facilities still populated
            return h;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenHostelDetailsController.getHostelDetails',
                'Unable to load hostel details.', e);
            return null;
        }
    }

    @AuraEnabled
    public static Id submitAllocationRequest(String roomType, String preference) {
        try {
            KenAuraExceptionHelper.rejectIf(String.isBlank(roomType), 'Room type is required.');
            // Map LWC labels onto the restricted Type__c picklist (Single/Shared/Triple).
            String dbType = 'Shared'; // safe default for any unrecognised value
            if (roomType.startsWithIgnoreCase('Single'))      dbType = 'Single';
            else if (roomType.startsWithIgnoreCase('Double')) dbType = 'Shared';
            else if (roomType.startsWithIgnoreCase('Triple')) dbType = 'Triple';
            Id studentId = KenRunningStudentHelper.optionalContactId();
            // Idempotency: skip if a Pending Request already exists for this student.
            if (studentId != null) {
                List<Hostel_Allocation__c> open = [
                    SELECT Id FROM Hostel_Allocation__c
                    WHERE Student__c = :studentId AND Status__c = 'Pending Request'
                    WITH SECURITY_ENFORCED LIMIT 1
                ];
                if (!open.isEmpty()) return open[0].Id;
            }
            KenCrudFlsHelper.assertCreateable(Hostel_Allocation__c.SObjectType);
            Hostel_Allocation__c r = new Hostel_Allocation__c(
                Student__c        = studentId,
                Type__c           = dbType,
                Status__c         = 'Pending Request',
                Request_Notes__c  = preference == null ? null : preference.left(1000)
            );
            insert r;
            // Notify the student so the request shows up in the bell.
            if (studentId != null && Schema.SObjectType.Student_Notification__c.isCreateable()) {
                insert new Student_Notification__c(
                    Student__c  = studentId,
                    Title__c    = 'Hostel allocation request submitted',
                    Body__c     = 'Your preference for a ' + dbType + ' room is awaiting warden review.',
                    Category__c = 'System',
                    Is_Read__c  = false
                );
            }
            return r.Id;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenHostelDetailsController.submitAllocationRequest',
                'Could not submit your allocation request.', e);
            return null;
        }
    }
}