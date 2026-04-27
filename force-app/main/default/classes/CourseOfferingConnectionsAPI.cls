@RestResource(urlMapping='/course-offering-connections')
global class CourseOfferingConnectionsAPI {
    global class Connections {
        public Id Id;
        public Id Course_OfferingId;
        public Id Learning_Program_PlanId;
        public String CourseOfferingName;
        public String LearningProgramPlanName;
        public String EnrollmentType;
        public Boolean IsMonday;
    }

    @HttpGet
    global static List<Connections> getConnections() {
        List<Connections> result = new List<Connections>();
        
        for (Program_Plan_Course_Junction__c p : [
            SELECT 
                Id,
                Course_Offering__c,
                Learning_Program_Plan__c,
                Course_Offering__r.Name,
                Learning_Program_Plan__r.Name,
                Enrollment_Type__c,
                IsMonday__c 
            FROM Program_Plan_Course_Junction__c
        ]) {
           
            Connections r = new Connections(); 
            r.Id = p.Id;
            r.CourseOfferingName = p.Course_Offering__r.Name;
            r.LearningProgramPlanName = p.Learning_Program_Plan__r.Name;
            r.IsMonday = p.IsMonday__c;
            r.Learning_Program_PlanId=p.Learning_Program_Plan__c;
           r.Course_OfferingId=p.Course_Offering__c;
            r.EnrollmentType = p.Enrollment_Type__c; 
            
            result.add(r);
        }
        return result;
    }
}