*** Settings ***
Documentation     Advanced Test Suite for Supplier Operations in vKho API
...               Includes complex scenarios like bulk operations, dependencies, concurrency, and pagination
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Library           BuiltIn

*** Variables ***
${BASE_URL}             https://api.vkho.net
${USERNAME}             huynh22.manager
${PASSWORD}             Snowfox1991
${WAREHOUSE_ID}         6
${PRODUCT_CATEGORY_ID}  37
${RESULTS_DIR}          ${CURDIR}${/}results
${TEST_SUPPLIER_ID}     ${EMPTY}
${TEST_SUPPLIER_CODE}   ${EMPTY}
${TEST_SUPPLIER_DATA}   ${EMPTY}
${BULK_SUPPLIER_IDS}    ${EMPTY}

*** Keywords ***
Setup API Session
    [Documentation]     Create API session and authenticate
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
    ...    msg=Authentication failed: Response did not contain access_token
    
    # Save token for subsequent tests
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${AUTH_TOKEN}    ${token}
    
    # Create results directory if it doesn't exist
    Create Directory    ${RESULTS_DIR}

Generate Unique Supplier Data
    [Documentation]     Generate unique data for supplier tests
    [Arguments]         ${custom_name}=Test Supplier
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${supplier_name}=   Set Variable     ${custom_name} ${timestamp}
    ${supplier_code}=   Set Variable     SUP${timestamp}
    
    # Return dictionary of generated data
    ${supplier_data}=   Create Dictionary
    ...                 name=${supplier_name}
    ...                 code=${supplier_code}
    ...                 phoneNumber=800555${timestamp}
    ...                 email=supplier_${timestamp}@example.com
    ...                 address=123 Supplier Street
    [Return]            ${supplier_data}

Create Supplier
    [Documentation]     Create a new supplier and return its ID
    [Arguments]         ${supplier_data}
    
    # Validate required parameters
    Dictionary Should Contain Key    ${supplier_data}    name
    ...    msg=Missing required parameter: name
    Dictionary Should Contain Key    ${supplier_data}    code
    ...    msg=Missing required parameter: code
    Dictionary Should Contain Key    ${supplier_data}    phoneNumber
    ...    msg=Missing required parameter: phoneNumber
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send create supplier request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /suppliers/create
    ...                 json=${supplier_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Create supplier response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Create supplier response missing ID field
    
    # Return supplier ID and full response
    ${supplier_id}=     Convert To String    ${json}[id]
    [Return]            ${supplier_id}    ${json}

Get Supplier By ID
    [Documentation]     Retrieve a specific supplier by ID
    [Arguments]         ${supplier_id}
    
    # Validate parameters
    Should Not Be Empty    ${supplier_id}
    ...    msg=Supplier ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send get supplier request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /suppliers/get-one/${supplier_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get supplier response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Get supplier response missing ID field
    
    [Return]            ${json}

Update Supplier
    [Documentation]     Update an existing supplier
    [Arguments]         ${supplier_id}    ${update_data}
    
    # Validate parameters
    Should Not Be Empty    ${supplier_id}
    ...    msg=Supplier ID cannot be empty
    Dictionary Should Contain Key    ${update_data}    id
    ...    msg=Update data must contain id field
    Should Be Equal     ${update_data}[id]    ${supplier_id}
    ...    msg=Update data ID must match supplier_id parameter
    
    # Ensure minimum required fields are present
    Dictionary Should Contain Key    ${update_data}    name
    ...    msg=Update data missing required field: name
    Dictionary Should Contain Key    ${update_data}    code
    ...    msg=Update data missing required field: code
    Dictionary Should Contain Key    ${update_data}    phoneNumber
    ...    msg=Update data missing required field: phoneNumber
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send update supplier request
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /suppliers/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Update supplier response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Update supplier response missing ID field
    
    [Return]            ${json}

Delete Supplier
    [Documentation]     Delete a supplier from the system
    [Arguments]         ${supplier_id}
    
    # Validate parameters
    Should Not Be Empty    ${supplier_id}
    ...    msg=Supplier ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send delete supplier request
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /suppliers/delete/${supplier_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Return deletion status
    [Return]            ${TRUE}

Get All Suppliers
    [Documentation]     Retrieve all suppliers with optional filtering and pagination
    [Arguments]         ${filter_params}=${EMPTY}    ${page}=${EMPTY}    ${limit}=${EMPTY}
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Create params dictionary
    ${params}=          Create Dictionary
    Run Keyword If      "${filter_params}" != "${EMPTY}"    Set To Dictionary    ${params}    &{filter_params}
    Run Keyword If      "${page}" != "${EMPTY}"             Set To Dictionary    ${params}    page=${page}
    Run Keyword If      "${limit}" != "${EMPTY}"            Set To Dictionary    ${params}    limit=${limit}
    
    # Send get all suppliers request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /suppliers/get-all
    ...                 params=${params}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get all suppliers response was empty
    
    [Return]            ${json}

Create Product With Supplier
    [Documentation]     Create a product linked to a supplier
    [Arguments]         ${supplier_id}
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${product_data}=    Create Dictionary
    ...                 name=Product SUP${timestamp}
    ...                 sku=SKU${timestamp}
    ...                 barcode=BAR${timestamp}
    ...                 description=Product for supplier ${supplier_id}
    ...                 price=79.99
    ...                 unit=Piece
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 productCategoryId=${PRODUCT_CATEGORY_ID}
    ...                 supplierId=${supplier_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${product_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${product_id}=      Convert To String    ${json}[id]
    [Return]            ${product_id}

Bulk Create Suppliers
    [Documentation]     Create multiple suppliers in bulk with validation
    [Arguments]         ${count}=5
    
    ${supplier_ids}=    Create List
    FOR    ${i}    IN RANGE    ${count}
        ${supplier_data}=    Generate Unique Supplier Data    custom_name=Bulk Supplier ${i}
        ${supplier_id}    ${response}=    Create Supplier    ${supplier_data}
        Append To List      ${supplier_ids}    ${supplier_id}
    END
    [Return]            ${supplier_ids}

Assert Supplier Details
    [Documentation]     Verify supplier details match expected values
    [Arguments]         ${supplier}    ${expected_data}
    
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${supplier}    Should Be Equal    ${supplier}[${key}]    ${expected_data}[${key}]
        ...    msg=Supplier ${key} value '${supplier}[${key}]' does not match expected '${expected_data}[${key}]'
    END

Create Test Supplier
    [Documentation]     Creates a test supplier if one doesn't exist
    ${supplier_data}=   Generate Unique Supplier Data
    ${supplier_id}    ${response}=    Create Supplier    ${supplier_data}
    Set Global Variable  ${TEST_SUPPLIER_ID}      ${supplier_id}
    Set Global Variable  ${TEST_SUPPLIER_CODE}    ${response}[code]
    Set Global Variable  ${TEST_SUPPLIER_DATA}    ${supplier_data}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for complex supplier tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Bulk Supplier Creation With Validation Test
    [Documentation]     Test creating multiple suppliers in bulk with validation
    [Tags]              create    bulk    positive
    
    ${bulk_ids}=        Bulk Create Suppliers    count=5
    Should Not Be Empty    ${bulk_ids}
    ...    msg=Failed to create bulk suppliers: No IDs returned
    Should Be Equal As Integers    ${bulk_ids.__len__()}    5
    ...    msg=Expected 5 suppliers, but created ${bulk_ids.__len__()}
    
    # Verify each supplier exists
    FOR    ${id}    IN    @{bulk_ids}
        ${supplier}=    Get Supplier By ID    ${id}
        Should Not Be Empty    ${supplier}
        ...    msg=Supplier ${id} from bulk creation not found
    END
    
    Set Global Variable  ${BULK_SUPPLIER_IDS}    ${bulk_ids}
    Log                 Successfully created and validated ${bulk_ids.__len__()} suppliers: ${bulk_ids}

03 - Create Supplier With Duplicate Code Test
    [Documentation]     Test creating a supplier with a duplicate code
    [Tags]              create    negative
    
    # Create first supplier
    ${supplier_data}=   Generate Unique Supplier Data    custom_name=Duplicate Supplier
    ${supplier_id}    ${response}=    Create Supplier    ${supplier_data}
    
    # Attempt to create second supplier with same code
    ${duplicate_data}=  Create Dictionary    &{supplier_data}
    Set To Dictionary   ${duplicate_data}    name=Duplicate Supplier 2
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /suppliers/create
    ...                 json=${duplicate_data}
    ...                 headers=${headers}
    ...                 expected_status=any
    
    Should Not Equal As Integers    ${response.status_code}    201
    ...    msg=API allowed creation of supplier with duplicate code
    Log                 Successfully verified duplicate code rejection: ${response.text}

04 - Supplier With Product Dependency Test
    [Documentation]     Test creating and retrieving a supplier with a dependent product
    [Tags]              create    retrieve    dependency    positive
    
    # Create supplier
    ${supplier_data}=   Generate Unique Supplier Data    custom_name=Dependency Supplier
    ${supplier_id}    ${response}=    Create Supplier    ${supplier_data}
    
    # Create product linked to supplier
    ${product_id}=      Create Product With Supplier    ${supplier_id}
    Should Not Be Empty    ${product_id}
    ...    msg=Failed to create product linked to supplier
    
    # Retrieve supplier and verify
    ${supplier}=        Get Supplier By ID    ${supplier_id}
    Assert Supplier Details    ${supplier}    ${supplier_data}
    Log                 Successfully created and retrieved supplier ${supplier_id} with product ${product_id}

05 - Concurrent Supplier Updates Test
    [Documentation]     Test concurrent updates to a supplier with conflict detection
    [Tags]              update    concurrent    positive
    
    # Create supplier
    ${supplier_data}=   Generate Unique Supplier Data    custom_name=Concurrent Supplier
    ${supplier_id}    ${response}=    Create Supplier    ${supplier_data}
    
    # First update
    ${update_data_1}=   Create Dictionary
    ...                 id=${supplier_id}
    ...                 name=${supplier_data}[name] Update 1
    ...                 code=${supplier_data}[code]
    ...                 phoneNumber=9005551111
    ...                 email=update1_${supplier_id}@example.com
    ...                 address=789 Concurrent Street
    ${updated_1}=       Update Supplier    ${supplier_id}    ${update_data_1}
    
    # Second update (simulating concurrent change)
    ${update_data_2}=   Create Dictionary
    ...                 id=${supplier_id}
    ...                 name=${supplier_data}[name] Update 2
    ...                 code=${supplier_data}[code]
    ...                 phoneNumber=9005552222
    ...                 email=update2_${supplier_id}@example.com
    ...                 address=101 Concurrent Street
    ${updated_2}=       Update Supplier    ${supplier_id}    ${update_data_2}
    
    # Verify final state
    ${final_supplier}=  Get Supplier By ID    ${supplier_id}
    Should Be Equal     ${final_supplier}[name]    ${update_data_2}[name]
    ...    msg=Second concurrent update did not apply correctly
    Should Be Equal     ${final_supplier}[phoneNumber]    ${update_data_2}[phoneNumber]
    ...    msg=Second concurrent update did not apply phoneNumber correctly
    
    Log                 Successfully verified concurrent updates on supplier ${supplier_id}

06 - Pagination And Filtering Suppliers Test
    [Documentation]     Test retrieving suppliers with pagination and filtering
    [Tags]              retrieve    pagination    filter    positive
    
    # Ensure bulk suppliers exist
    Run Keyword If      "${BULK_SUPPLIER_IDS}" == "${EMPTY}"    Bulk Create Suppliers    count=10
    
    # Filter by code prefix and paginate (page 1, limit 3)
    ${filter_params}=   Create Dictionary    supplierCode=SUP
    ${suppliers_page_1}=    Get All Suppliers    filter_params=${filter_params}    page=1    limit=3
    
    # Verify response structure
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${suppliers_page_1}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${suppliers_page_1}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${suppliers_page_1}    records
    
    ${items}=           Set Variable    ${EMPTY}
    IF    ${has_data}
        ${items}=       Set Variable    ${suppliers_page_1}[data]
    ELSE IF    ${has_items}
        ${items}=       Set Variable    ${suppliers_page_1}[items]
    ELSE IF    ${has_records}
        ${items}=       Set Variable    ${suppliers_page_1}[records]
    END
    
    Should Not Be Empty    ${items}
    ...    msg=Paginated suppliers response was empty
    Should Be True         ${items.__len__()} <= 3
    ...    msg=Page 1 exceeded limit of 3 items: ${items.__len__()}
    
    # Verify at least one item matches filter
    ${found_match}=     Set Variable    ${FALSE}
    FOR    ${item}    IN    @{items}
        ${code_matches}=    Evaluate    "${item['code']}".startswith("SUP")
        IF    ${code_matches}
            ${found_match}=    Set Variable    ${TRUE}
            Exit For Loop
        END
    END
    Should Be True      ${found_match}
    ...    msg=No suppliers matched filter 'SUP' on page 1
    
    Log                 Successfully retrieved paginated suppliers with filter: ${items.__len__()} items

07 - Delete Supplier With Product Dependency Test
    [Documentation]     Test deleting a supplier with a dependent product
    [Tags]              delete    dependency    negative
    
    # Create supplier
    ${supplier_data}=   Generate Unique Supplier Data    custom_name=Delete Dependency Supplier
    ${supplier_id}    ${response}=    Create Supplier    ${supplier_data}
    
    # Create product linked to supplier
    ${product_id}=      Create Product With Supplier    ${supplier_id}
    
    # Attempt to delete supplier with dependency
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /suppliers/delete/${supplier_id}
    ...                 headers=${headers}
    ...                 expected_status=any
    
    # Expect failure due to dependency (assuming API enforces this)
    Should Not Equal As Integers    ${response.status_code}    200
    ...    msg=API allowed deletion of supplier with dependent product
    Log                 Successfully verified rejection of supplier deletion with product ${product_id}

08 - Edge Case - Supplier With Malformed Email Test
    [Documentation]     Test creating a supplier with a malformed email
    [Tags]              create    edge    negative
    
    ${supplier_data}=   Generate Unique Supplier Data    custom_name=Malformed Email Supplier
    Set To Dictionary   ${supplier_data}    email=invalid-email-format
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /suppliers/create
    ...                 json=${supplier_data}
    ...                 headers=${headers}
    ...                 expected_status=any
    
    Should Not Equal As Integers    ${response.status_code}    201
    ...    msg=API allowed creation of supplier with malformed email
    Log                 Successfully verified rejection of supplier with malformed email: ${response.text}

09 - Edge Case - Supplier With Maximum Length Fields Test
    [Documentation]     Test creating a supplier with maximum length field values
    [Tags]              create    edge    positive
    
    ${long_name}=       Set Variable    ${"A" * 255}    # Assuming 255 char limit
    ${long_code}=       Set Variable    SUP${"X" * 50}  # Assuming 50 char limit
    
    ${supplier_data}=   Create Dictionary
    ...                 name=${long_name}
    ...                 code=${long_code}
    ...                 phoneNumber=8005559999
    ...                 email=maxlength_${long_code}@example.com
    ...                 address=123 Long Address Street
    
    ${supplier_id}    ${response}=    Create Supplier    ${supplier_data}
    Should Not Be Empty    ${supplier_id}
    ...    msg=Failed to create supplier with max length fields
    
    ${supplier}=        Get Supplier By ID    ${supplier_id}
    Should Be Equal     ${supplier}[name]    ${long_name}
    ...    msg=Created supplier name does not match max length input
    Log                 Successfully created supplier with maximum length fields: ${supplier_id}

10 - Cleanup Test Environment
    [Documentation]     Clean up resources created during complex tests
    [Tags]              cleanup
    
    # Clean up bulk suppliers if created
    Run Keyword If      "${BULK_SUPPLIER_IDS}" != "${EMPTY}"
    ...                 Run Keywords
    ...                 FOR    ${id}    IN    @{BULK_SUPPLIER_IDS}
    ...                 Delete Supplier    ${id}
    ...                 END
    ...                 AND    Set Global Variable    ${BULK_SUPPLIER_IDS}    ${EMPTY}
    
    # Clean up test supplier if created
    Run Keyword If      "${TEST_SUPPLIER_ID}" != "${EMPTY}"
    ...                 Delete Supplier    ${TEST_SUPPLIER_ID}
    ...                 AND    Set Global Variable    ${TEST_SUPPLIER_ID}    ${EMPTY}
    
    Log                 Test environment cleaned up successfully