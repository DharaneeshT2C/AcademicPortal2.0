@RestResource(urlMapping='/course-offerings')
global with sharing class CourseOfferingAPI {

    // Wrapper class
    global class CourseOfferingData {
        public Id Id;
        public String AcademicSessionName;
        public String PrimaryFacultyName;
        public String Course_Type;
        public Decimal Credit;
        public Integer EnrolleeCount;
    }

    @HttpGet
    global static List<CourseOfferingData> getCourseOfferings() {

        List<CourseOfferingData> result = new List<CourseOfferingData>();

        List<CourseOffering> offerings = [
            SELECT Id,
                   AcademicSession.Name,
                   PrimaryFaculty.Name,
                   Course_Type__c,
                   Credit__c,
                   EnrolleeCount
            FROM CourseOffering
        ];

        for(CourseOffering o : offerings){
            CourseOfferingData data = new CourseOfferingData();

            data.Id = o.Id;
            data.AcademicSessionName = o.AcademicSession.Name;
            data.PrimaryFacultyName = o.PrimaryFaculty.Name;
            data.Course_Type = o.Course_Type__c;
            data.Credit = o.Credit__c;
            data.EnrolleeCount=o.EnrolleeCount;

            result.add(data);
        }

        return result;
    }
}