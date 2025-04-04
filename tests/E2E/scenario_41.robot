*** Settings ***
Documentation     Advanced Test Suite for Warehouse Operations in vKho API
...               Includes complex scenarios like bulk operations, dependencies, and edge cases
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Library           BuiltIn
Resource          ../../Variables/variables.robot

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

Generate Unique Warehouse Data
    [Documentation]     Generate unique data for warehouse tests
    [Arguments]         ${custom_name}=Test Warehouse
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${warehouse_name}=  Set Variable     ${custom_name} ${timestamp}
    ${code}=            Set Variable     WH${timestamp}
    
    # Return dictionary of generated data
    ${warehouse_data}=  Create Dictionary
    ...                 name=${warehouse_name}
    ...                 code=${code}
    ...                 address=456 Warehouse Lane
    ...                 phoneNumber=800555${timestamp}
    ...                 email=warehouse_${timestamp}@example.com
    RETURN            ${warehouse_data}

Create Warehouse
    [Documentation]     Create a new warehouse and return its ID
    [Arguments]         ${warehouse_data}
    
    # Validate required parameters
    Dictionary Should Contain Key    ${warehouse_data}    name
    ...    msg=Missing required parameter: name
    Dictionary Should Contain Key    ${warehouse_data}    code
    ...    msg=Missing required parameter: code
    Dictionary Should Contain Key    ${warehouse_data}    address
    ...    msg=Missing required parameter: address
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send create warehouse request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /warehouses/create
    ...                 json=${warehouse_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Create warehouse response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Create warehouse response missing ID field
    
    # Return warehouse ID and full response
    ${warehouse_id}=    Convert To String    ${json}[id]
    RETURN            ${warehouse_id}    ${json}

Get Warehouse By ID
    [Documentation]     Retrieve a specific warehouse by ID
    [Arguments]         ${warehouse_id}
    
    # Validate parameters
    Should Not Be Empty    ${warehouse_id}
    ...    msg=Warehouse ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send get warehouse request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /warehouses/get-one/${warehouse_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get warehouse response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Get warehouse response missing ID field
    
    RETURN            ${json}

Update Warehouse
    [Documentation]     Update an existing warehouse
    [Arguments]         ${warehouse_id}    ${update_data}
    
    # Validate parameters
    Should Not Be Empty    ${warehouse_id}
    ...    msg=Warehouse ID cannot be empty
    Dictionary Should Contain Key    ${update_data}    id
    ...    msg=Update data must contain id field
    Should Be Equal     ${update_data}[id]    ${warehouse_id}
    ...    msg=Update data ID must match warehouse_id parameter
    
    # Ensure minimum required fields are present
    Dictionary Should Contain Key    ${update_data}    name
    ...    msg=Update data missing required field: name
    Dictionary Should Contain Key    ${update_data}    code
    ...    msg=Update data missing required field: code
    Dictionary Should Contain Key    ${update_data}    address
    ...    msg=Update data missing required field: address
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send update warehouse request
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /warehouses/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Update warehouse response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Update warehouse response missing ID field
    
    RETURN            ${json}

Delete Warehouse
    [Documentation]     Delete a warehouse from the system
    [Arguments]         ${warehouse_id}
    
    # Validate parameters
    Should Not Be Empty    ${warehouse_id}
    ...    msg=Warehouse ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send delete warehouse request
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /warehouses/delete/${warehouse_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Return deletion status
    RETURN            ${TRUE}

Get All Warehouses
    [Documentation]     Retrieve all warehouses with optional filtering
    [Arguments]         ${filter_params}=${EMPTY}
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Create params dictionary if filters are provided
    ${params}=          Create Dictionary
    Run Keyword If      "${filter_params}" != "${EMPTY}"    Set To Dictionary    ${params}    &{filter_params}
    
    # Send get all warehouses request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /warehouses/get-all
    ...                 params=${params}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get all warehouses response was empty
    
    RETURN            ${json}

Create Product In Warehouse
    [Documentation]     Create a product linked to a warehouse
    [Arguments]         ${warehouse_id}
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${product_data}=    Create Dictionary
    ...                 name=Product WH${timestamp}
    ...                 sku=SKU${timestamp}
    ...                 barcode=BAR${timestamp}
    ...                 description=Product in warehouse ${warehouse_id}
    ...                 price=49.99
    ...                 unit=Piece
    ...                 warehouseId=${warehouse_id}
    ...                 productCategoryId=${PRODUCT_CATEGORY_ID}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${product_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${product_id}=      Convert To String    ${json}[id]
    RETURN            ${product_id}

Bulk Create Warehouses
    [Documentation]     Create multiple warehouses in bulk
    [Arguments]         ${count}=3
    
    ${warehouse_ids}=   Create List
    FOR    ${i}    IN RANGE    ${count}
        ${warehouse_data}=  Generate Unique Warehouse Data    custom_name=Bulk Warehouse ${i}
        ${warehouse_id}    ${response}=    Create Warehouse    ${warehouse_data}
        Append To List      ${warehouse_ids}    ${warehouse_id}
    END
    RETURN            ${warehouse_ids}

Assert Warehouse Details
    [Documentation]     Verify warehouse details match expected values
    [Arguments]         ${warehouse}    ${expected_data}
    
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${warehouse}    Should Be Equal    ${warehouse}[${key}]    ${expected_data}[${key}]
        ...    msg=Warehouse ${key} value '${warehouse}[${key}]' does not match expected '${expected_data}[${key}]'
    END

Create Test Warehouse
    [Documentation]     Creates a test warehouse if one doesn't exist
    ${warehouse_data}=  Generate Unique Warehouse Data
    ${warehouse_id}    ${response}=    Create Warehouse    ${warehouse_data}
    Set Global Variable  ${TEST_WAREHOUSE_ID}      ${warehouse_id}
    Set Global Variable  ${TEST_WAREHOUSE_NAME}    ${response}[name]
    Set Global Variable  ${TEST_WAREHOUSE_DATA}    ${warehouse_data}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for complex warehouse tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Bulk Warehouse Creation Test
    [Documentation]     Test creating multiple warehouses in bulk
    [Tags]              create    bulk    positive
    
    ${bulk_ids}=        Bulk Create Warehouses    count=3
    Should Not Be Empty    ${bulk_ids}
    ...    msg=Failed to create bulk warehouses: No IDs returned
    Should Be Equal As Integers    ${bulk_ids.__len__()}    3
    ...    msg=Expected 3 warehouses, but created ${bulk_ids.__len__()}
    
    Set Global Variable  ${BULK_WAREHOUSE_IDS}    ${bulk_ids}
    Log                 Successfully created ${bulk_ids.__len__()} warehouses: ${bulk_ids}

03 - Create Warehouse With Duplicate Code Test
    [Documentation]     Test creating a warehouse with a duplicate code
    [Tags]              create    negative
    
    # Create first warehouse
    ${warehouse_data}=  Generate Unique Warehouse Data    custom_name=Duplicate Code WH
    ${warehouse_id}    ${response}=    Create Warehouse    ${warehouse_data}
    
    # Attempt to create second warehouse with same code
    ${duplicate_data}=  Create Dictionary    &{warehouse_data}
    Set To Dictionary   ${duplicate_data}    name=Duplicate WH 2
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /warehouses/create
    ...                 json=${duplicate_data}
    ...                 headers=${headers}
    ...                 expected_status=any
    
    Should Not Equal As Integers    ${response.status_code}    201
    ...    msg=API allowed creation of warehouse with duplicate code
    Log                 Successfully verified duplicate code rejection: ${response.text}

04 - Warehouse With Product Dependency Test
    [Documentation]     Test creating and retrieving a warehouse with a dependent product
    [Tags]              create    retrieve    dependency    positive
    
    # Create warehouse
    ${warehouse_data}=  Generate Unique Warehouse Data    custom_name=Dependency WH
    ${warehouse_id}    ${response}=    Create Warehouse    ${warehouse_data}
    
    # Create product in warehouse
    ${product_id}=      Create Product In Warehouse    ${warehouse_id}
    Should Not Be Empty    ${product_id}
    ...    msg=Failed to create product in warehouse
    
    # Retrieve warehouse and verify
    ${warehouse}=       Get Warehouse By ID    ${warehouse_id}
    Assert Warehouse Details    ${warehouse}    ${warehouse_data}
    Log                 Successfully created and retrieved warehouse ${warehouse_id} with product ${product_id}

05 - Update Warehouse With Concurrent Changes Test
    [Documentation]     Test updating a warehouse with simulated concurrent changes
    [Tags]              update    concurrent    positive
    
    # Create warehouse
    ${warehouse_data}=  Generate Unique Warehouse Data    custom_name=Concurrent WH
    ${warehouse_id}    ${response}=    Create Warehouse    ${warehouse_data}
    
    # First update
    ${update_data_1}=   Create Dictionary
    ...                 id=${warehouse_id}
    ...                 name=${warehouse_data}[name] Update 1
    ...                 code=${warehouse_data}[code]
    ...                 address=789 Concurrent Lane
    ...                 phoneNumber=9005551111
    ...                 email=update1_${warehouse_id}@example.com
    ${updated_1}=       Update Warehouse    ${warehouse_id}    ${update_data_1}
    
    # Second update (simulating concurrent change)
    ${update_data_2}=   Create Dictionary
    ...                 id=${warehouse_id}
    ...                 name=${warehouse_data}[name] Update 2
    ...                 code=${warehouse_data}[code]
    ...                 address=101 Concurrent Lane
    ...                 phoneNumber=9005552222
    ...                 email=update2_${warehouse_id}@example.com
    ${updated_2}=       Update Warehouse    ${warehouse_id}    ${update_data_2}
    
    # Verify final state
    ${final_warehouse}=    Get Warehouse By ID    ${warehouse_id}
    Should Be Equal     ${final_warehouse}[name]    ${update_data_2}[name]
    ...    msg=Concurrent update did not apply correctly
    Should Be Equal     ${final_warehouse}[address]    ${update_data_2}[address]
    ...    msg=Concurrent update did not apply address correctly
    
    Log                 Successfully verified concurrent updates on warehouse ${warehouse_id}

06 - Filter Warehouses By Multiple Criteria Test
    [Documentation]     Test filtering warehouses with multiple parameters
    [Tags]              retrieve    filter    positive
    
    # Create test warehouse if not exists
    Run Keyword If      "${TEST_WAREHOUSE_ID}" == "${EMPTY}"    Create Test Warehouse
    
    # Filter by name and code
    ${filter_params}=   Create Dictionary
    ...                 warehouseName=${TEST_WAREHOUSE_NAME}
    ...                 warehouseCode=${TEST_WAREHOUSE_DATA}[code]
    
    ${filtered_warehouses}=    Get All Warehouses    filter_params=${filter_params}
    Should Not Be Empty    ${filtered_warehouses}
    ...    msg=Filtered warehouses response was empty
    
    # Check response structure and verify result
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_warehouses}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_warehouses}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_warehouses}    records
    
    ${found}=           Set Variable    ${FALSE}
    IF    ${has_data}
        ${data_length}=     Get Length    ${filtered_warehouses}[data]
        Should Be True      ${data_length} > 0    msg=Filter returned empty data array
        ${found}=           Set Variable    ${TRUE}
    ELSE IF    ${has_items}
        ${items_length}=    Get Length    ${filtered_warehouses}[items]
        Should Be True      ${items_length} > 0    msg=Filter returned empty items array
        ${found}=           Set Variable    ${TRUE}
    ELSE IF    ${has_records}
        ${records_length}=  Get Length    ${filtered_warehouses}[records]
        Should Be True      ${records_length} > 0    msg=Filter returned empty records array
        ${found}=           Set Variable    ${TRUE}
    END
    
    Should Be True      ${found}    msg=Failed to find warehouse with multiple filters
    Log                 Successfully filtered warehouses with name: ${TEST_WAREHOUSE_NAME} and code: ${TEST_WAREHOUSE_DATA}[code]

07 - Delete Warehouse With Dependencies Test
    [Documentation]     Test deleting a warehouse with a dependent product
    [Tags]              delete    dependency    negative
    
    # Create warehouse
    ${warehouse_data}=  Generate Unique Warehouse Data    custom_name=Dependency Delete WH
    ${warehouse_id}    ${response}=    Create Warehouse    ${warehouse_data}
    
    # Create product in warehouse
    ${product_id}=      Create Product In Warehouse    ${warehouse_id}
    
    # Attempt to delete warehouse with dependency
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /warehouses/delete/${warehouse_id}
    ...                 headers=${headers}
    ...                 expected_status=any
    
    # Expect failure due to dependency (assuming API enforces this)
    Should Not Equal As Integers    ${response.status_code}    200
    ...    msg=API allowed deletion of warehouse with dependent product
    Log                 Successfully verified rejection of warehouse deletion with product ${product_id}

08 - Edge Case - Warehouse With Maximum Length Fields Test
    [Documentation]     Test creating a warehouse with maximum length field values
    [Tags]              create    edge    positive
    
    ${long_name}=       Set Variable    ${"A" * 255}    # Assuming 255 char limit
    ${long_code}=       Set Variable    WH${"X" * 50}   # Assuming 50 char limit for code
    
    ${warehouse_data}=  Create Dictionary
    ...                 name=${long_name}
    ...                 code=${long_code}
    ...                 address=123 Long Address Street
    ...                 phoneNumber=8005559999
    ...                 email=maxlength@example.com
    
    ${warehouse_id}    ${response}=    Create Warehouse    ${warehouse_data}
    Should Not Be Empty    ${warehouse_id}
    ...    msg=Failed to create warehouse with max length fields
    
    ${warehouse}=       Get Warehouse By ID    ${warehouse_id}
    Should Be Equal     ${warehouse}[name]    ${long_name}
    ...    msg=Created warehouse name does not match max length input
    Log                 Successfully created warehouse with maximum length fields: ${warehouse_id}

09 - Cleanup Test Environment
    [Documentation]     Clean up resources created during complex tests
    [Tags]              cleanup
    
    # Clean up bulk warehouses if created
    Run Keyword If      "${BULK_WAREHOUSE_IDS}" != "${EMPTY}"
    ...                 Run Keywords
    ...                 FOR    ${id}    IN    @{BULK_WAREHOUSE_IDS}
    ...                 Delete Warehouse    ${id}
    ...                 END
    ...                 AND    Set Global Variable    ${BULK_WAREHOUSE_IDS}    ${EMPTY}
    
    # Clean up test warehouse if created
    Run Keyword If      "${TEST_WAREHOUSE_ID}" != "${EMPTY}"
    ...                 Delete Warehouse    ${TEST_WAREHOUSE_ID}
    ...                 AND    Set Global Variable    ${TEST_WAREHOUSE_ID}    ${EMPTY}
    
    Log                 Test environment cleaned up successfully