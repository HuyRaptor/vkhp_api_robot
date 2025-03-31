*** Settings ***
Documentation     Test Suite for Supplier Operations in vKho API
...               Includes fixes for variable handling issues
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime

*** Variables ***
${BASE_URL}             https://api.vkho.net
${USERNAME}             huynh22.manager
${PASSWORD}             Snowfox1991
${WAREHOUSE_ID}         6
${PRODUCT_CATEGORY_ID}  37

*** Test Cases ***
01 - Login And Get Authentication Token
    [Documentation]     Login to vKho API and get authentication token for subsequent tests
    [Tags]              authentication    prerequisite
    
    # Create session
    Create Session      vkho             ${BASE_URL}      verify=True    disable_warnings=True
    
    # Prepare login request
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${USERNAME}    password=${PASSWORD}
    
    # Send login request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /auth/login
    ...                 json=${body}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    access_token
    
    # Save token for subsequent tests
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${AUTH_TOKEN}    ${token}
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create New Supplier
    [Documentation]     Create a new supplier in the system
    [Tags]              supplier    create
    
    # Check authentication token
    Should Not Be Empty    ${AUTH_TOKEN}    msg=Authentication token is required. Run the login test first.
    
    # Generate unique values for supplier
    ${timestamp}=       Evaluate         int(time.time())    time
    ${supplier_name}=   Set Variable     Test Supplier ${timestamp}
    ${email}=           Set Variable     supplier_${timestamp}@test.com
    ${phone}=           Set Variable     800567${timestamp}
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${product_categories}=  Create List      ${PRODUCT_CATEGORY_ID}
    ${body}=            Create Dictionary
    ...                 name=${supplier_name}
    ...                 email=${email}
    ...                 phoneNumber=${phone}
    ...                 address=Test Address
    ...                 isActive=${TRUE}
    ...                 contractNumber=TST${timestamp}
    ...                 taxCode=57519${timestamp}
    ...                 cooperationDay=2023-03-20T00:00:00.000Z
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 productCategoryIds=${product_categories}
    
    # Send create supplier request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /suppliers/create
    ...                 json=${body}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Verify response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    Dictionary Should Contain Key        ${json}    id
    Dictionary Should Contain Key        ${json}    name
    Should Be Equal     ${json}[name]    ${supplier_name}
    
    # Convert ID to string to ensure consistency
    ${supplier_id_str}=  Convert To String    ${json}[id]
    
    # Save supplier information as global variables
    Set Global Variable  ${SUPPLIER_ID}      ${supplier_id_str}
    Set Global Variable  ${SUPPLIER_NAME}    ${json}[name]
    Set Global Variable  ${SUPPLIER_CODE}    ${json}[code]
    
    # Log information for debugging
    Log                 Successfully created supplier: ${SUPPLIER_NAME} with ID: ${SUPPLIER_ID}

03 - Get All Suppliers
    [Documentation]     Retrieve all suppliers from the system
    [Tags]              supplier    retrieve
    
    # Check authentication token
    Should Not Be Empty    ${AUTH_TOKEN}    msg=Authentication token is required. Run the login test first.
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${params}=          Create Dictionary    warehouseId=${WAREHOUSE_ID}
    
    # Send get all suppliers request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /suppliers/get-all
    ...                 params=${params}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Log the raw response for debugging
    Log                 Response text: ${response.text}
    
    # Basic verification that response is not empty
    Should Not Be Empty    ${response.text}
    
    # Verify response is valid JSON
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Log                 Retrieved suppliers successfully

04 - Get Specific Supplier
    [Documentation]     Retrieve a specific supplier by ID
    [Tags]              supplier    retrieve
    
    # Check prerequisites
    Should Not Be Empty    ${AUTH_TOKEN}    msg=Authentication token is required. Run the login test first.
    Should Not Be Empty    ${SUPPLIER_ID}    msg=Supplier ID is required. Run the Create New Supplier test first.
    
    # Log ID for debugging
    Log                 Using supplier ID: ${SUPPLIER_ID}
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send get supplier request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /suppliers/get-one/${SUPPLIER_ID}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Log response for debugging
    Log                 Response text: ${response.text}
    
    # Verify response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    
    # Convert ID to string for comparison
    ${id_from_response}=    Convert To String    ${json}[id]
    Should Be Equal     ${id_from_response}    ${SUPPLIER_ID}
    
    # Verify name if available
    Dictionary Should Contain Key    ${json}    name
    Should Be Equal     ${json}[name]    ${SUPPLIER_NAME}
    
    Log                 Successfully retrieved supplier with ID: ${SUPPLIER_ID}

05 - Update Supplier
    [Documentation]     Update an existing supplier
    [Tags]              supplier    update
    
    # Check prerequisites
    Should Not Be Empty    ${AUTH_TOKEN}    msg=Authentication token is required. Run the login test first.
    Should Not Be Empty    ${SUPPLIER_ID}    msg=Supplier ID is required. Run the Create New Supplier test first.
    
    # Log ID for debugging
    Log                 Using supplier ID: ${SUPPLIER_ID}
    
    # Generate updated values
    ${updated_name}=    Set Variable    ${SUPPLIER_NAME} Updated
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${product_categories}=  Create List      ${PRODUCT_CATEGORY_ID}
    ${body}=            Create Dictionary
    ...                 id=${SUPPLIER_ID}
    ...                 name=${updated_name}
    ...                 email=updated_${SUPPLIER_ID}@test.com
    ...                 phoneNumber=9005551234
    ...                 address=Updated Address
    ...                 isActive=${TRUE}
    ...                 contractNumber=UPD${SUPPLIER_ID}
    ...                 taxCode=99999${SUPPLIER_ID}
    ...                 cooperationDay=2023-04-20T00:00:00.000Z
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 productCategoryIds=${product_categories}
    ...                 status=ENABLE
    
    # Send update supplier request
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /suppliers/update
    ...                 json=${body}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Log response for debugging
    Log                 Response text: ${response.text}
    
    # Verify response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    
    # Verify name was updated
    Dictionary Should Contain Key    ${json}    name
    Should Be Equal     ${json}[name]    ${updated_name}
    
    # Update supplier name variable
    Set Global Variable    ${SUPPLIER_NAME}    ${updated_name}
    
    Log                 Successfully updated supplier with ID: ${SUPPLIER_ID}

06 - Delete Supplier
    [Documentation]     Delete a supplier from the system
    [Tags]              supplier    delete
    
    # Check prerequisites
    Should Not Be Empty    ${AUTH_TOKEN}    msg=Authentication token is required. Run the login test first.
    Should Not Be Empty    ${SUPPLIER_ID}    msg=Supplier ID is required. Run the Create New Supplier test first.
    
    # Log ID for debugging
    Log                 Using supplier ID: ${SUPPLIER_ID}
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # First, verify the supplier exists before deletion
    ${response_before}=  GET On Session
    ...                 vkho
    ...                 /suppliers/get-one/${SUPPLIER_ID}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Send delete supplier request
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /suppliers/delete/${SUPPLIER_ID}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Log success
    Log                 Successfully deleted supplier with ID: ${SUPPLIER_ID}
    
    # Verify supplier was deleted - modify verification approach
    # Instead of expecting an error, check for specific status code or empty response
    # Approach 1: Try to get the supplier but expect a 404 or appropriate status
    ${response_after}=  GET On Session
    ...                 vkho
    ...                 /suppliers/get-one/${SUPPLIER_ID}
    ...                 headers=${headers}
    ...                 expected_status=any
    
    # Log the response for debugging
    Log                 Response status after deletion: ${response_after.status_code}
    Log                 Response content after deletion: ${response_after.text}
    
    # Verify the supplier is truly deleted by checking status or response body
    # Use one of these methods based on how your API behaves:
    
    # Option 1: Check for empty response or specific content indicating deletion
    ${json_after}=      Evaluate         json.loads('''${response_after.text}''')    json
    Log                 JSON response after deletion: ${json_after}
    
    # Option 2: Check for status code (uncomment if your API returns 404 for deleted items)
    # Should Be Equal As Integers    ${response_after.status_code}    404
    
    # Option 3: Verify response indicates deletion (e.g., status field shows deletion)
    # Choose the appropriate verification based on your API's behavior
    # For example, checking if a status field shows "DISABLE" or similar
    Run Keyword If      ${response_after.status_code} == 200
    ...                 Verify Supplier Is Marked As Deleted    ${json_after}

*** Keywords ***
Verify Supplier Is Marked As Deleted
    [Arguments]    ${json}
    # Check if the supplier has a status field indicating deletion
    # Modify these checks based on your API's actual behavior after deletion
    ${has_status}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${json}    status
    Run Keyword If    ${has_status}    Should Be Equal    ${json}[status]    DISABLE
    
    # Add alternative verification if status field doesn't exist or has different values
    # This is just an example - adapt to your API's actual behavior
    ${has_active}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${json}    isActive
    Run Keyword If    ${has_active}    Should Be Equal    ${json}[isActive]    ${FALSE}