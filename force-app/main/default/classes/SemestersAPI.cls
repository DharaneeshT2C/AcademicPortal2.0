@RestResource(urlMapping='/semesters')
global with sharing class SemestersAPI {

   
    global class Semester {
        public Id Id;
        public String Name;
        public Id Program_Plan;
        public Id Course_Offering;
        public DateTime ClassStartDate;
        public DateTime ClassEndDate;
        public String Type;
        public Decimal Term_Duration;
        public String Term_Status;
        public STring Term_Reference;
    }

    @HttpGet
    global static List<Semester> getSemesters() {

        List<Semester> semesterList = new List<Semester>();

        for(Program_Plan_Course_Junction__c s : [
            SELECT 
    Id, 
    Learning_Program_Plan__c, 
    Course_Offering__c,
    Course_Offering__r.AcademicSession.Duration_in_Weeks__c, 
    Course_Offering__r.AcademicSession.Term_Status__c, 
    Course_Offering__r.AcademicSession.Cadence_Period__c,
    Course_Offering__r.AcademicSession.Id,
    Course_Offering__r.AcademicSessioN.Name,
    Course_Offering__r.AcademicSession.ClassStartDate,
    Course_Offering__r.AcademicSession.ClassEndDate,
    Course_Offering__r.AcademicSession.Type
FROM Program_Plan_Course_Junction__c
WHERE Learning_Program_Plan__c != NULL 
  AND Course_Offering__c != NULL 
  AND Course_Offering__r.AcademicSessionId  != NULL
        ]) {
            Semester sem = new Semester();
            sem.Id = s.Course_Offering__r.AcademicSession.Id;
            sem.Name = s.Course_Offering__r.AcademicSessioN.Name;
            sem.ClassStartDate = s.Course_Offering__r.AcademicSession.ClassStartDate;
            sem.ClassEndDate = s.Course_Offering__r.AcademicSession.ClassEndDate;
            sem.Type = s.Course_Offering__r.AcademicSession.Type;
            sem.Term_Duration=s.Course_Offering__r.AcademicSession.Duration_in_Weeks__c;
            sem.Term_Status=s.Course_Offering__r.AcademicSession.Term_Status__c;
            sem.Term_Reference=s.Course_Offering__r.AcademicSession.Cadence_Period__c;
            sem.Program_Plan=s.Learning_Program_Plan__c;
            sem.Course_Offering=s.Course_Offering__c;
            

            semesterList.add(sem);
        }

        return semesterList;
    }
}