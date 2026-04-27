@RestResource(urlMapping='/student-participants')
global with sharing class StudentParticipantsAPI {

    global class StudentParticipantDTO{
        public Id Id;
        public String Term;
        public Id CourseOfferingId;
        public String CourseOfferingName;
        public String ParticipantContactName;
        public String ParticipationStatus;
        public String ParticipantAffiliation;
    }

    @HttpGet
    global static List<StudentParticipantDTO> getStudentParticipants(){

        List<StudentParticipantDTO> result = new List<StudentParticipantDTO>();

        for(CourseOfferingParticipant p : [
            SELECT Id,
                   CourseOffering.Name,
                   Academic_Term__c,
                   CourseOfferingId, 
                   ParticipantContact.Name,
                   ParticipationStatus,
                   ParticipantAffiliation
            FROM CourseOfferingParticipant
            WHERE ParticipantAffiliation='Student'
        ]){

            StudentParticipantDTO dto = new StudentParticipantDTO();
            dto.Id = p.Id;
            dto.CourseOfferingId = p.CourseOfferingId;
            dto.Term=p.Academic_Term__c;
            dto.CourseOfferingName = p.CourseOffering.Name;
            dto.ParticipantContactName = p.ParticipantContact.Name;
            dto.ParticipationStatus = p.ParticipationStatus;
            dto.ParticipantAffiliation = p.ParticipantAffiliation;

            result.add(dto);
        }

        return result;
    }
}