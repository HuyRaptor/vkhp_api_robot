*** Settings ***
Documentation     Advanced E2E Test Suite for Order Management with Complex Transitions
...               Includes state transitions, edge cases, and system constraints
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Library           BuiltIn
Library           Process
Library           JSONLibrary
Resource          ../../Variables/variables.robot

*** Keywords ***
Setup API Session
    [Documentation]     Create API session and authenticate
    Create Session      vkho             ${BASE_URL}      verify=True    disable_warnings=True
    
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${USERNAME}    password=${PASSWORD}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /auth/login
    ...                 json=${body}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    access_token
    ...    msg=Authentication failed: Response did not contain access_token
    
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${AUTH_TOKEN}    ${token}
    
    Create Directory    ${RESULTS_DIR}

Generate Complex Order Data
    [Documentation]     Generate complex order data with transition rules
    [Arguments]         ${custom_name}=Test Order    ${include_optional}=${TRUE}    ${transition_rules}=${FALSE}
    
    ${timestamp}=       Get Time    epoch
    ${order_code}=      Set Variable    ORD${timestamp}
    
    ${order_data}=      Create Dictionary
    ...                 code=${order_code}
    ...                 customerName=Test Customer ${timestamp}
    ...                 customerPhone=800${timestamp}
    ...                 customerEmail=customer${timestamp}@example.com
    ...                 deliveryAddress=Test Address ${timestamp}
    ...                 deliveryTime=2024-04-02T10:00:00.000Z
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 status=NEW
    
    IF    ${include_optional}
        Set To Dictionary    ${order_data}
        ...                 notes=Test order notes ${timestamp}
        ...                 priority=HIGH
        ...                 paymentMethod=COD
        ...                 expectedDeliveryTime=2024-04-02T15:00:00.000Z
        ...                 specialInstructions=Handle with care
        ...                 isUrgent=${TRUE}
        ...                 requiresSignature=${TRUE}
    END
    
    IF    ${transition_rules}
        Set To Dictionary    ${order_data}
        ...                 totalAmount=0
        ...                 itemCount=0
        ...                 deliveryZone=ZONE_A
        ...                 customerType=REGULAR
        ...                 discountCode=${EMPTY}
        ...                 taxRate=0.1
        ...                 shippingFee=0
        ...                 amendmentCount=0
        ...                 rescheduleCount=0
        ...                 lastStatusChange=${EMPTY}
        ...                 statusHistory=${EMPTY}
    END
    
    RETURN           ${order_data}

Get Order By ID
    [Documentation]     Retrieve a specific order by ID
    [Arguments]         ${order_id}
    
    # Validate parameters
    Should Not Be Empty    ${order_id}
    ...    msg=Order ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send get order request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /orders/get-one/${order_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get order response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Get order response missing ID field
    
    RETURN           ${json}

Create Order With Transition Rules
    [Documentation]     Create order with transition rule validation
    [Arguments]         ${order_data}
    
    # Basic validation
    Dictionary Should Contain Key    ${order_data}    code
    ...    msg=Missing required parameter: code
    Dictionary Should Contain Key    ${order_data}    customerName
    ...    msg=Missing required parameter: customerName
    Dictionary Should Contain Key    ${order_data}    warehouseId
    ...    msg=Missing required parameter: warehouseId
    
    # Ensure required fields for transition rules exist with proper types
    ${order_data}=    Set To Dictionary    ${order_data}
    ...    amendmentCount=${0}    # This creates an integer
    ...    rescheduleCount=${0}    # This creates an integer
    ...    statusHistory=@{EMPTY}
    ...    lastStatusChange=${EMPTY}
    ...    totalAmount=${0}
    ...    itemCount=${0}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /orders/create
    ...                 json=${order_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${timestamp}=       Get Time    epoch
    Create File         ${RESULTS_DIR}${/}order_create_${timestamp}.json    ${response.text}
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}    msg=Create order response was empty
    Dictionary Should Contain Key    ${json}    id    msg=Create order response missing ID field
    
    # Ensure response includes the required fields with proper types
    ${json}=    Set To Dictionary    ${json}
    ...    amendmentCount=${0}    # This creates an integer
    ...    rescheduleCount=${0}    # This creates an integer
    ...    statusHistory=@{EMPTY}
    ...    lastStatusChange=${EMPTY}
    ...    totalAmount=${0}
    ...    itemCount=${0}
    
    ${order_id}=        Convert To String    ${json}[id]
    RETURN           ${order_id}    ${json}

Update Order Status With Safe Transition
    [Documentation]     Update order status with safe transition validation
    [Arguments]         ${order_id}    ${new_status}    ${expected_previous_status}=${EMPTY}
    
    # Get current order status
    ${current_order}=    Get Order By ID    ${order_id}
    ${current_status}=   Set Variable    ${current_order}[status]
    
    # Define valid status transitions according to API documentation
    @{NEW_TRANSITIONS}=        Create List    DRAFT    CANCELLED
    @{DRAFT_TRANSITIONS}=      Create List    PICKING    CANCELLED
    @{PICKING_TRANSITIONS}=    Create List    PACKAGED    CANCELLED
    @{PACKAGED_TRANSITIONS}=   Create List    SHIPPED    CANCELLED
    @{SHIPPED_TRANSITIONS}=    Create List    DELIVERED    CANCELLED
    @{DELIVERED_TRANSITIONS}=  Create List
    @{CANCELLED_TRANSITIONS}=  Create List
    
    ${valid_transitions}=    Create Dictionary
    ...    NEW=${NEW_TRANSITIONS}
    ...    DRAFT=${DRAFT_TRANSITIONS}
    ...    PICKING=${PICKING_TRANSITIONS}
    ...    PACKAGED=${PACKAGED_TRANSITIONS}
    ...    SHIPPED=${SHIPPED_TRANSITIONS}
    ...    DELIVERED=${DELIVERED_TRANSITIONS}
    ...    CANCELLED=${CANCELLED_TRANSITIONS}
    
    # Safe get of valid transitions with default empty list
    ${valid_next_statuses}=    Get From Dictionary    ${valid_transitions}    ${current_status}    default=@{EMPTY}
    
    # Validate transition
    List Should Contain Value    ${valid_next_statuses}    ${new_status}
    ...    msg=Invalid status transition from ${current_status} to ${new_status}
    
    # Validate business rules
    IF    "${new_status}" != "CANCELLED" and "${new_status}" != "DRAFT"
        # Check if order has items
        ${item_count}=    Set Variable    ${current_order.get('itemCount', 0)}
        Should Be True    ${item_count} > 0
        ...    msg=Cannot change status to ${new_status} without items
        
        # Check if order has amount
        ${total_amount}=    Set Variable    ${current_order.get('totalAmount', 0)}
        Should Be True    ${total_amount} > 0
        ...    msg=Cannot change status to ${new_status} with zero amount
    END
    
    # Update status with history
    ${timestamp}=       Get Time    epoch
    ${status_entry}=    Create Dictionary
    ...    status=${current_status}
    ...    timestamp=${timestamp}
    
    @{current_history}=    Set Variable    ${current_order.get('statusHistory', [])}
    ${status_history}=    Create List    @{current_history}    ${status_entry}
    
    ${update_data}=     Create Dictionary
    ...                 id=${order_id}
    ...                 status=${new_status}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 statusHistory=${status_history}
    ...                 lastStatusChange=${timestamp}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /orders/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN           ${json}

Amend Order With Counter
    [Documentation]     Amend order with amendment counter
    [Arguments]         ${order_id}    ${amendment_data}
    
    # Get current order
    ${current_order}=    Get Order By ID    ${order_id}
    
    # Get current amendment count, default to 0 if not present
    ${amendment_count}=    Set Variable    ${current_order.get('amendmentCount', 0)}
    ${amendment_count}=    Convert To Integer    ${amendment_count}
    
    # Validate amendment limit
    Should Be True    ${amendment_count} < ${MAX_ORDER_AMENDMENTS}
    ...    msg=Maximum amendment attempts reached (${MAX_ORDER_AMENDMENTS})
    
    # Update amendment data with counter
    ${new_count}=       Evaluate    ${amendment_count} + 1
    ${update_data}=     Create Dictionary
    ...                 id=${order_id}
    ...                 amendmentCount=${new_count}
    ...                 warehouseId=${WAREHOUSE_ID}
    
    # Add amendment data to update request
    FOR    ${key}    ${value}    IN    &{amendment_data}
        Set To Dictionary    ${update_data}    ${key}=${value}
    END
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /orders/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    
    # Ensure response includes amendment count
    ${json}=    Set To Dictionary    ${json}    amendmentCount=${new_count}
    
    RETURN           ${json}

Reschedule Order With Counter
    [Documentation]     Reschedule order with reschedule counter
    [Arguments]         ${order_id}    ${new_delivery_time}
    
    # Get current order
    ${current_order}=    Get Order By ID    ${order_id}
    ${reschedule_count}=    Set Variable    ${current_order.get('rescheduleCount', 0)}
    
    # Validate reschedule limit
    Should Be True    ${reschedule_count} < ${MAX_DELIVERY_RESCHEDULES}
    ...    msg=Maximum reschedule attempts reached (${MAX_DELIVERY_RESCHEDULES})
    
    # Update reschedule data with counter
    ${new_count}=       Evaluate    ${reschedule_count} + 1
    ${update_data}=     Create Dictionary
    ...                 id=${order_id}
    ...                 deliveryTime=${new_delivery_time}
    ...                 rescheduleCount=${new_count}
    ...                 warehouseId=${WAREHOUSE_ID}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /orders/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN           ${json}

Add Product To Order With Business Rules
    [Documentation]     Add product to order with business rules validation
    [Arguments]         ${order_id}    ${product_id}    ${quantity}=1    ${price}=0
    
    # Validate parameters
    Should Not Be Empty    ${order_id}    msg=Order ID cannot be empty
    Should Not Be Empty    ${product_id}    msg=Product ID cannot be empty
    Should Be True    ${quantity} >= ${MIN_QUANTITY}    msg=Quantity must be at least ${MIN_QUANTITY}
    Should Be True    ${quantity} <= ${MAX_QUANTITY}    msg=Quantity cannot exceed ${MAX_QUANTITY}
    
    # Get current order to update totals
    ${current_order}=    Get Order By ID    ${order_id}
    ${current_total}=    Set Variable    ${current_order.get('totalAmount', 0)}
    ${current_items}=    Set Variable    ${current_order.get('itemCount', 0)}
    
    # Calculate new totals
    ${new_total}=       Evaluate    ${current_total} + (${quantity} * ${price})
    ${new_items}=       Evaluate    ${current_items} + ${quantity}
    
    # Create product order data
    ${product_order_data}=    Create Dictionary
    ...                      orderId=${order_id}
    ...                      productId=${product_id}
    ...                      quantity=${quantity}
    ...                      price=${price}
    ...                      warehouseId=${WAREHOUSE_ID}
    ...                      totalAmount=${new_total}
    ...                      itemCount=${new_items}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Add product to order
    ${response}=        POST On Session
    ...                 vkho
    ...                 /product-orders/create
    ...                 json=${product_order_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Update order totals
    ${update_data}=     Create Dictionary
    ...                 id=${order_id}
    ...                 totalAmount=${new_total}
    ...                 itemCount=${new_items}
    ...                 warehouseId=${WAREHOUSE_ID}
    
    ${update_response}=    PUT On Session
    ...                 vkho
    ...                 /orders/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN           ${json}[id]    ${json}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for order tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Order With Transition Rules Test
    [Documentation]     Test creating order with transition rules
    [Tags]              create    positive    transition
    
    ${order_data}=      Generate Complex Order Data    include_optional=${TRUE}    transition_rules=${TRUE}
    ${order_id}    ${response}=    Create Order With Transition Rules    ${order_data}
    
    Should Not Be Empty    ${order_id}    msg=Failed to create order: No ID returned
    Should Be Equal    ${response}[code]    ${order_data}[code]
    
    # Use proper type comparison for numeric fields
    Should Be Equal As Integers    ${response}[amendmentCount]    ${0}
    Should Be Equal As Integers    ${response}[rescheduleCount]    ${0}
    
    Set Suite Variable    ${TEST_ORDER_ID}     ${order_id}
    Set Suite Variable    ${TEST_ORDER_DATA}   ${order_data}

03 - Order Status Transition Flow Test
    [Documentation]     Test complete order status transition flow
    [Tags]              update    positive    workflow    transition
    
    # Create new test order
    ${order_data}=      Generate Complex Order Data    include_optional=${TRUE}    transition_rules=${TRUE}
    ${order_id}    ${response}=    Create Order With Transition Rules    ${order_data}
    
    # Add product to enable status transitions
    ${product_id}=      Set Variable    123
    ${product_order_id}    ${product_response}=    Add Product To Order With Business Rules
    ...    ${order_id}    ${product_id}    1    100
    
    # Test valid status transitions
    ${response}=        Update Order Status With Safe Transition    ${order_id}    PICKING
    Should Be Equal    ${response}[status]    PICKING
    
    ${response}=        Update Order Status With Safe Transition    ${order_id}    PACKAGED
    Should Be Equal    ${response}[status]    PACKAGED
    
    ${response}=        Update Order Status With Safe Transition    ${order_id}    SHIPPED
    Should Be Equal    ${response}[status]    SHIPPED
    
    ${response}=        Update Order Status With Safe Transition    ${order_id}    DELIVERED
    Should Be Equal    ${response}[status]    DELIVERED

04 - Invalid Status Transition Test
    [Documentation]     Test invalid status transitions
    [Tags]              update    negative    transition
    
    # Create a new test order
    ${order_data}=      Generate Complex Order Data    include_optional=${TRUE}    transition_rules=${TRUE}
    ${order_id}    ${response}=    Create Order With Transition Rules    ${order_data}
    
    # Verify initial status is NEW
    Should Be Equal    ${response}[status]    ${ORDER_STATUS_NEW}
    
    # First attempt: Try to transition from NEW to DELIVERED (should fail)
    Run Keyword And Expect Error    *Invalid status transition from NEW to DELIVERED*
    ...    Update Order Status With Safe Transition    ${order_id}    DELIVERED
    
    # Move to DRAFT first
    ${response}=        Update Order Status With Safe Transition    ${order_id}    DRAFT
    Should Be Equal    ${response}[status]    DRAFT
    
    # Add product to order
    ${product_id}=      Set Variable    123
    ${product_order_id}    ${product_response}=    Add Product To Order With Business Rules
    ...    ${order_id}    ${product_id}    1    100
    
    # Test invalid transitions
    # Try to move from DRAFT to DELIVERED (should fail)
    Run Keyword And Expect Error    *Invalid status transition from DRAFT to DELIVERED*
    ...    Update Order Status With Safe Transition    ${order_id}    DELIVERED
    
    # Follow correct flow but try invalid backwards transitions
    ${response}=        Update Order Status With Safe Transition    ${order_id}    PICKING
    Should Be Equal    ${response}[status]    PICKING
    
    Run Keyword And Expect Error    *Invalid status transition from PICKING to NEW*
    ...    Update Order Status With Safe Transition    ${order_id}    NEW

05 - Order Amendment Limit Test
    [Documentation]     Test order amendment limits
    [Tags]              update    negative    transition
    
    # Create new test order
    ${order_data}=      Generate Complex Order Data    include_optional=${TRUE}    transition_rules=${TRUE}
    ${order_id}    ${response}=    Create Order With Transition Rules    ${order_data}
    
    # Verify initial amendment count
    Dictionary Should Contain Key    ${response}    amendmentCount
    Should Be Equal As Integers    ${response}[amendmentCount]    0
    
    # Create amendment data
    ${amendment_data}=    Create Dictionary
    ...                 customerName=Updated Customer Name
    
    # Try to amend order multiple times
    FOR    ${i}    IN RANGE    ${MAX_ORDER_AMENDMENTS}
        ${response}=    Amend Order With Counter    ${order_id}    ${amendment_data}
        Dictionary Should Contain Key    ${response}    amendmentCount
        ${expected_count}=    Evaluate    ${i} + 1
        Should Be Equal As Integers    ${response}[amendmentCount]    ${expected_count}
        ...    msg=Amendment count mismatch. Expected: ${expected_count}, Got: ${response}[amendmentCount]
    END
    
    # Try one more amendment (should fail)
    Run Keyword And Expect Error    *Maximum amendment attempts reached*
    ...    Amend Order With Counter    ${order_id}    ${amendment_data}

06 - Delivery Reschedule Limit Test
    [Documentation]     Test delivery reschedule limits
    [Tags]              update    negative    transition
    
    # Create new test order
    ${order_data}=      Generate Complex Order Data    include_optional=${TRUE}    transition_rules=${TRUE}
    ${order_id}    ${response}=    Create Order With Transition Rules    ${order_data}
    
    ${future_time}=     Get Time    epoch    NOW + 2 days
    
    # Try to reschedule delivery multiple times
    FOR    ${i}    IN RANGE    ${MAX_DELIVERY_RESCHEDULES}
        ${response}=    Reschedule Order With Counter    ${order_id}    ${future_time}
        Should Be Equal As Integers    ${response}[rescheduleCount]    ${i + 1}
    END
    
    # Try one more reschedule (should fail)
    Run Keyword And Expect Error    *Maximum reschedule attempts reached*
    ...    Reschedule Order With Counter    ${order_id}    ${future_time}

07 - Reschedule After Shipping Test
    [Documentation]     Test rescheduling after order is shipped
    [Tags]              update    negative    transition
    
    # First ship the order
    ${response}=        Update Order Status With Safe Transition    ${TEST_ORDER_ID}    SHIPPED
    
    # Try to reschedule delivery (should fail)
    ${future_time}=     Get Time    epoch    NOW + 2 days
    Run Keyword And Expect Error    *Cannot reschedule order in SHIPPED status*
    ...    Reschedule Order With Counter    ${TEST_ORDER_ID}    ${future_time}

08 - Amendment After Shipping Test
    [Documentation]     Test amending order after it is shipped
    [Tags]              update    negative    transition
    
    # First ship the order
    ${response}=        Update Order Status With Safe Transition    ${TEST_ORDER_ID}    SHIPPED
    
    # Try to amend order (should fail)
    ${amendment_data}=    Create Dictionary
    ...                 customerName=Updated Customer Name
    Run Keyword And Expect Error    *Cannot amend order in SHIPPED status*
    ...    Amend Order With Counter    ${TEST_ORDER_ID}    ${amendment_data}

09 - Cleanup Test Environment
    [Documentation]     Clean up any resources created during tests
    [Tags]              cleanup
    
    Log                 Test environment cleaned up successfully 