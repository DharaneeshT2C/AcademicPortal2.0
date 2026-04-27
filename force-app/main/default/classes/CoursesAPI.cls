@RestResource(urlMapping='/courses')

global with Sharing class CoursesAPI {

    global class Courses{
        public Id Id;
        public Id ProviderId;
        public String ProviderName;       
        public String Name;
        public Decimal Duration;
        public String CourseType;
        public Decimal Credit1;
}

    @HttpGet
    global static List<Courses> getCourses(){

        List<Courses>result=new list<Courses>();

        for(LearningCourse c:[SELECT Id, Name, Duration, Credit_1__c, CourseType, ProviderId, Provider.Name
FROM LearningCourse 
WHERE Provider.Record_Type_Name__c   = 'Department']){

                Courses r=new Courses();
                r.Id=c.Id;
                r.Name=c.Name;
                r.Duration=c.Duration;
                r.ProviderId=c.ProviderId;
                r.ProviderName=c.Provider.Name;
                r.CourseType=c.CourseType;
                r.Credit1=c.Credit_1__c;
                result.add(r);

            }

        return result;

        

        

    }

    



}