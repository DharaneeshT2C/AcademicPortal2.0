@RestResource(urlMapping='/facilities')
global with sharing class FacilitiesAPI {

    global class FacilitiesDTO{
        public Id Id;
        public Id ProviderId;
        public String ProviderName;
        public String Name;
        public Integer MaximumOccupancy;
        public String LocationType;
        public String Description;
    }

    @HttpGet
    global static List<FacilitiesDTO> getFacilities(){

        List<FacilitiesDTO> result = new List<FacilitiesDTO>();

        for(Schema.Location loc : [
            SELECT Id, Name, MaximumOccupancy, LocationType, Description,Provider__c, Provider__r.Name
            FROM Location
        ]){

            FacilitiesDTO r = new FacilitiesDTO();
            r.Id = loc.Id;
            r.Name = loc.Name;
            r.MaximumOccupancy = loc.MaximumOccupancy;
            r.LocationType = loc.LocationType;
            r.Description = loc.Description;
            r.ProviderId=loc.Provider__c;
            r.ProviderName=loc.Provider__r.Name;
            result.add(r);
        }

        return result;
    }
}