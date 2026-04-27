@RestResource(urlMapping='/organization-default-settings')
global with sharing class OrganizationDefaultsRestApi {
    global class RestPayload {
        public Boolean success;
        public String message;
        public String primary;
        public String secondary;
        public String instituteName;
        public String instituteAlias;
    }

    @HttpGet
    global static void getOrganizationDefaults() {
        RestResponse response = RestContext.response;
        response.addHeader('Content-Type', 'application/json');

        RestPayload payload = new RestPayload();
        try {
            OrganizationDefaultsApiController.OrganizationDefaultsResponse defaultsData =
                OrganizationDefaultsApiController.getOrganizationDefaults();

            payload.success = true;
            payload.message = 'Organization defaults fetched successfully.';
            payload.primary = defaultsData == null ? null : defaultsData.primary;
            payload.secondary = defaultsData == null ? null : defaultsData.secondary;
            payload.instituteName = defaultsData == null ? null : defaultsData.instituteName;
            payload.instituteAlias = defaultsData == null ? null : defaultsData.instituteAlias;
            response.statusCode = 200;
        } catch (Exception e) {
            payload.success = false;
            payload.message = e.getMessage();
            payload.primary = null;
            payload.secondary = null;
            payload.instituteName = null;
            payload.instituteAlias = null;
            response.statusCode = 500;
        }

        response.responseBody = Blob.valueOf(JSON.serialize(payload));
    }
}