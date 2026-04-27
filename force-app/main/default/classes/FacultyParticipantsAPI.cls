@RestResource(urlMapping='/faculty-participants')
global with sharing class FacultyParticipantsAPI {

    global class FacultyParticipantDTO{
        public Id Id;
        public Id CourseOfferingId;
        public String CourseOfferingName;
        public String ParticipantContactName;
        public String ParticipationStatus;
        public String ParticipantAffiliation;
    }

    @HttpGet
    global static List<FacultyParticipantDTO> getFacultyParticipants(){

        List<FacultyParticipantDTO> result = new List<FacultyParticipantDTO>();

        for(CourseOfferingParticipant p : [
            SELECT Id,
            CourseOfferingId,
                   CourseOffering.Name,
                   ParticipantContact.Name,
                   ParticipationStatus,
                   ParticipantAffiliation
            FROM CourseOfferingParticipant
            WHERE ParticipantAffiliation='Faculty'
        ]){

            FacultyParticipantDTO dto = new FacultyParticipantDTO();
            dto.Id = p.Id;
            dto.CourseOfferingId=p.CourseOfferingId;
            dto.CourseOfferingName = p.CourseOffering.Name;
            dto.ParticipantContactName= p.ParticipantContact.Name;
            dto.ParticipationStatus = p.ParticipationStatus;
            dto.ParticipantAffiliation = p.ParticipantAffiliation;

            result.add(dto);
        }

        return result;
    }
}