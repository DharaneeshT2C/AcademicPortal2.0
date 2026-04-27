/**
 * ************************************************************************************************
 * @className  KenClubsController
 *
 * @description
 *  Backs the `my/clubs` LWC page — lists student clubs with category filters and
 *  handles "express interest" / join requests.
 *
 *  TODO[SOBJECT]: Wire to `Club__c` and `Club_Membership__c`.
 * ************************************************************************************************
 */
public with sharing class KenClubsController {

    public class ClubDTO {
        @AuraEnabled public String  id;
        @AuraEnabled public String  name;
        @AuraEnabled public String  category;
        @AuraEnabled public String  description;
        @AuraEnabled public Integer memberCount;
        @AuraEnabled public Boolean isJoined;
        @AuraEnabled public String  imageUrl;
    }

    @AuraEnabled(cacheable=true)
    public static List<ClubDTO> getClubs(String category) {
        try {
            // Pull live Club__c rows; figure out which ones the running student
            // has joined to set isJoined.
            List<Club__c> rows = [
                SELECT Id, Name, Category__c, Description__c, Member_Count__c, Image_Url__c
                FROM Club__c
                WITH USER_MODE
                ORDER BY Name
                LIMIT 200
            ];
            if (rows.isEmpty()) {
                List<ClubDTO> all = seedClubs();
                if (String.isBlank(category) || category == 'All') return all;
                List<ClubDTO> f = new List<ClubDTO>();
                for (ClubDTO c : all) if (c.category == category) f.add(c);
                return f;
            }
            // Joined-club ids for the running student
            Set<Id> joined = new Set<Id>();
            Id contactId = KenRunningStudentHelper.optionalContactId();
            if (contactId != null) {
                for (Club_Membership__c m : [
                    SELECT Club__c FROM Club_Membership__c
                    WHERE Student__c = :contactId AND Status__c IN ('Active','Interested')
                    WITH USER_MODE
                ]) joined.add(m.Club__c);
            }
            List<ClubDTO> out = new List<ClubDTO>();
            for (Club__c r : rows) {
                if (!String.isBlank(category) && category != 'All' && r.Category__c != category) continue;
                ClubDTO d = new ClubDTO();
                d.id          = r.Id;
                d.name        = r.Name;
                d.category    = r.Category__c;
                d.description = r.Description__c;
                d.memberCount = r.Member_Count__c == null ? 0 : r.Member_Count__c.intValue();
                d.isJoined    = joined.contains(r.Id);
                d.imageUrl    = r.Image_Url__c;
                out.add(d);
            }
            return out;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenClubsController.getClubs',
                'Unable to load clubs.', e);
            return null;
        }
    }

    @AuraEnabled
    public static void expressInterest(Id clubId) {
        try {
            KenAuraExceptionHelper.rejectIf(clubId == null, 'Club id is required.');
            Id studentId = KenRunningStudentHelper.optionalContactId();
            if (studentId == null) return; // anonymous; nothing to record
            // Idempotency: skip if the student already has an active/interested membership
            // in this club. Prevents double-click duplicates.
            List<Club_Membership__c> existing = [
                SELECT Id, Status__c FROM Club_Membership__c
                WHERE Club__c = :clubId AND Student__c = :studentId
                WITH USER_MODE LIMIT 1
            ];
            if (!existing.isEmpty()) return;
            KenCrudFlsHelper.assertCreateable(Club_Membership__c.SObjectType);
            insert new Club_Membership__c(
                Club__c    = clubId,
                Student__c = studentId,
                Status__c  = 'Interested'
            );
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenClubsController.expressInterest',
                'Could not register your interest.', e);
        }
    }

    @AuraEnabled
    public static ClubDTO createClub(String name, String category, String description) {
        try {
            KenAuraExceptionHelper.rejectIf(String.isBlank(name), 'Club name is required.');
            KenAuraExceptionHelper.rejectIf(String.isBlank(category), 'Club category is required.');
            // Map LWC labels onto the restricted Category__c picklist if needed.
            Set<String> validCats = new Set<String>{ 'Technical', 'Cultural', 'Arts', 'Sports' };
            if (!validCats.contains(category)) category = 'Cultural';
            KenCrudFlsHelper.assertCreateable(Club__c.SObjectType);
            Club__c c = new Club__c(
                Name           = name,
                Category__c    = category,
                Description__c = description,
                Member_Count__c = 1
            );
            insert c;
            // Auto-add the founder as a member.
            Id studentId = KenRunningStudentHelper.optionalContactId();
            if (studentId != null && Schema.SObjectType.Club_Membership__c.isCreateable()) {
                insert new Club_Membership__c(
                    Club__c    = c.Id,
                    Student__c = studentId,
                    Status__c  = 'Active'
                );
            }
            // Notify
            if (studentId != null && Schema.SObjectType.Student_Notification__c.isCreateable()) {
                insert new Student_Notification__c(
                    Student__c  = studentId,
                    Title__c    = 'Club submitted for review',
                    Body__c     = '"' + name + '" is awaiting admin approval.',
                    Category__c = 'System',
                    Is_Read__c  = false
                );
            }
            ClubDTO d = new ClubDTO();
            d.id          = c.Id;
            d.name        = name;
            d.category    = category;
            d.description = description;
            d.memberCount = 1;
            d.isJoined    = true;
            d.imageUrl    = '';
            return d;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenClubsController.createClub',
                'Could not create the club. Please try again.', e);
            return null;
        }
    }

    private static List<ClubDTO> seedClubs() {
        List<ClubDTO> out = new List<ClubDTO>();
        out.add(club('CL001', 'Coding Club',         'Technical',   'Hackathons, weekly build sessions, mentorship.', 248, false, ''));
        out.add(club('CL002', 'UI/UX Society',       'Technical',   'Design critiques, workshops, portfolio reviews.', 132, true,  ''));
        out.add(club('CL003', 'Debate Club',         'Cultural',    'MUN, parliamentary debate, public speaking.',     86,  false, ''));
        out.add(club('CL004', 'Photography Society', 'Arts',        'Photo walks, workshops, annual exhibition.',     104, false, ''));
        out.add(club('CL005', 'Sports Council',      'Sports',      'Inter-college tournaments, fitness drives.',     310, false, ''));
        return out;
    }

    private static ClubDTO club(String id, String name, String cat, String descText, Integer count, Boolean joined, String img) {
        ClubDTO c = new ClubDTO();
        c.id = id; c.name = name; c.category = cat; c.description = descText;
        c.memberCount = count; c.isJoined = joined; c.imageUrl = img;
        return c;
    }
}