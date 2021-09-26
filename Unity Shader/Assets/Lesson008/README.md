# 实时阴影介绍
项目地址：[here](https://github.com/logic-three-body/SimpleTalkCpp_UnityExamples/tree/main/Unity%20Shader/Assets/Lesson008)


## 阴影系统


阴影贴图技术是最常用的阴影生成技术，核心思想是在光源处构建相机，渲染深度图（称为shadow map），之后在真正的相机渲染时，将像素转换至光源空间，计算深度值并和shadow map中的深度值比较确定此像素是否在阴影中。
### Shadow Map
#### 构建深度图

首先在光源处构建相加，并渲染深度图（通过render texture），投影的类型及其相关参数会影响光源空间的投影矩阵，一般平行光适合利用正交投影，聚光灯适合利用透视投影（其投射光的形式和投影视锥体形状有关系）。
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632580678886-1be95ba0-4ee0-4d57-88e1-ff72da553444.png#clientId=u92d89d6d-6bf2-4&from=paste&height=185&id=u98685de2&margin=%5Bobject%20Object%5D&name=image.png&originHeight=1023&originWidth=1926&originalType=binary&ratio=1&size=290594&status=done&style=shadow&taskId=udacbc9b8-f42f-47c8-becb-cc2fd454fc8&width=349)  

![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632580834156-d971c7a2-57b2-4165-b7eb-d711fa81edf0.png#clientId=u92d89d6d-6bf2-4&from=paste&height=189&id=u83e6fa60&margin=%5Bobject%20Object%5D&name=image.png&originHeight=1036&originWidth=1926&originalType=binary&ratio=1&size=293946&status=done&style=shadow&taskId=uab0fec12-f417-4071-8216-fde7e10027c&width=351)
利用C#脚本设置相机渲染方式，渲染深度图

```csharp
var m = cam.projectionMatrix * cam.worldToCameraMatrix;
Shader.SetGlobalMatrix("MyShadowVP", m);
cam.targetTexture = shadowMap;
cam.SetReplacementShader(shader, null);
```
```cpp
float4x4  MyShadowVP;//lightspace matrix proj*view

v2f vs_main (appdata v) {
    v2f o;

    float4 wpos = mul(unity_ObjectToWorld, v.pos);
    o.pos = mul(MyShadowVP, wpos);//trans to light space
    float d = o.pos.z / o.pos.w;//perspective division
    d = d * 0.5 + 0.5;//NDC


    o.depth = d;
    return o;
}

float4 ps_main (v2f i) : SV_Target {
    return float4(i.depth, 0,0,1);//output depth color
}
```
此时渲染的正交图和透视图
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632581239996-688fc91e-0f6d-4d3a-87a7-ecf36ab38560.png#clientId=u92d89d6d-6bf2-4&from=paste&height=178&id=ubce22ecb&margin=%5Bobject%20Object%5D&name=image.png&originHeight=356&originWidth=358&originalType=binary&ratio=1&size=9005&status=done&style=shadow&taskId=u7acdb4e8-fb30-46c2-a7fc-026859e1f09&width=179)	![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632581215018-338e6d32-f4c0-4858-8775-c0da649c14f5.png#clientId=u92d89d6d-6bf2-4&from=paste&height=179&id=uf53a7715&margin=%5Bobject%20Object%5D&name=image.png&originHeight=357&originWidth=359&originalType=binary&ratio=1&size=14623&status=done&style=shadow&taskId=u3a874c79-27e8-4daf-b6ce-baaeb018171&width=179.5)
#### 阴影映射
下面进入重头戏，阴影映射。
顶点着色器,利用光源转换矩阵MyShadowVP(即cam.projectionMatrix * cam.worldToCameraMatrix)，将转换到光源坐标的数值保存起来，传到片元着色器。
```c
v2f vs_main (appdata v) {
    v2f o;
    o.pos = UnityObjectToClipPos(v.pos);
    //...some code
    float4 wpos = mul(unity_ObjectToWorld, v.pos);//world pos
    // transform coordinates into Light Space 
    o.shadowPos = mul(MyShadowVP, wpos);//light space clip space
    o.shadowPos.xyz /= o.shadowPos.w;//prespective division
    return o;
}
```
片元着色器有两个关键深度，current_depth表示当前视点转换到光源空间的深度，orgin_depth表示记录在shadow map深度图，离光源最近的深度，两者比较，若current_depth>orgin_depth说明比光源记录最近深度深，被遮挡，应该为阴影（黑色）
```c
float shadow(v2f i)
{
    // transform coordinates into texture coordinates [shadow map]
    float4 s = i.shadowPos;
    float3 shadow_uv = s.xyz * 0.5 + 0.5;
    float current_depth = shadow_uv.z;	//fragment depth in shadow map	
    float orgin_depth=0.0;
    orgin_depth=tex2D(MyShadowMap, shadow_uv).r;//depth in shadow map,the closest point towards light
    float shadow = 0.0;
    shadow = shadowMap(current_depth,orgin_depth);//get depth value					    
    return float4(shadow,shadow,shadow,1);
}
float shadowMap(float d1,float d2)
{
    return d1<=d2;//true : not shadow , false in the shadow
}
```
### ![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632582246098-0e3d6cfb-25fa-41be-9b51-1cacaf4cb8f6.png#clientId=u92d89d6d-6bf2-4&from=paste&height=418&id=u5b777a3d&margin=%5Bobject%20Object%5D&name=image.png&originHeight=835&originWidth=1384&originalType=binary&ratio=1&size=240878&status=done&style=none&taskId=u4aaa91c0-c5b1-4a9e-8b71-2485f250344&width=692)
上图渲染出来后有什么问题呢，上述经典问题是阴影粉刺【shadow acne】,由于阴影贴图分辨率影响（离散像素），每个阴影纹素对应场景某一区域，于是可能出现本该均在阴影外的点，一个在阴影内，一个在阴影外。【更多信息可用关注learnopengl或《DX12游戏开发实战第20章》】
#### 阴影偏移
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632582524024-aee8f4f0-0dca-45a9-9264-ada95fd2b300.png#clientId=u92d89d6d-6bf2-4&from=paste&height=286&id=u5082dcd1&margin=%5Bobject%20Object%5D&name=image.png&originHeight=572&originWidth=973&originalType=binary&ratio=1&size=199961&status=done&style=none&taskId=ube4d22f9-2341-4f1e-aaf0-73452511cfd&width=486.5)
解决此问题方式是增加阴影偏移（除了常数偏移，也可以根据多边形斜率控制偏移量）：
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632582683437-d48b4974-534e-4258-a782-002f88179ec5.png#clientId=u92d89d6d-6bf2-4&from=paste&height=219&id=ub7ab4adb&margin=%5Bobject%20Object%5D&name=image.png&originHeight=601&originWidth=984&originalType=binary&ratio=1&size=210136&status=done&style=shadow&taskId=u543b0964-170e-4862-98dd-3b58fa39130&width=358)![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632583054628-77777e75-2a8d-476a-ad9c-22d41ea04fd7.png#clientId=u92d89d6d-6bf2-4&from=paste&height=284&id=ub67f2e06&margin=%5Bobject%20Object%5D&name=image.png&originHeight=560&originWidth=635&originalType=binary&ratio=1&size=87412&status=done&style=shadow&taskId=u64c43a35-537e-402c-b9d0-7fb3451ba9e&width=322.5)
```c
//shadow bias
float slope = 1.0;
if(true)//bias according to slope
{
    float3 N = normalize(i.normal);
    float3 L = normalize(-MyLightDir.xyz);
    slope = tan(acos(dot(N,L)));
}
float _bias = shadowBias*slope;
current_depth-=_bias;
```
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632582789505-5759d919-51fb-4ac1-b42c-e674a21b350f.png#clientId=u92d89d6d-6bf2-4&from=paste&height=510&id=u23ee7650&margin=%5Bobject%20Object%5D&name=image.png&originHeight=1020&originWidth=1926&originalType=binary&ratio=1&size=238988&status=done&style=none&taskId=uaf1f5707-9400-4380-ba64-23c71fd9062&width=963)
注意，较大的偏移会产生peter-panning失真现象
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632585514065-27778fd2-cf16-4ffe-9662-7b8bf30d94d9.png#clientId=u92d89d6d-6bf2-4&from=paste&height=330&id=ubaaa7a3b&margin=%5Bobject%20Object%5D&name=image.png&originHeight=659&originWidth=1926&originalType=binary&ratio=1&size=123234&status=done&style=none&taskId=u808e497a-f639-4c68-a322-77bc7c97367&width=963)
#### 正交/透视下渲染的阴影
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632583255140-9b58cb1c-2e34-49f5-bf91-1ae1c77d747e.png#clientId=u92d89d6d-6bf2-4&from=paste&height=249&id=u19c197a6&margin=%5Bobject%20Object%5D&name=image.png&originHeight=498&originWidth=714&originalType=binary&ratio=1&size=21675&status=done&style=none&taskId=uafa89248-b082-4848-bf02-e77ea52fcca&width=357) ![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632583305030-b55e5fa8-0e2a-4c6e-9138-e458dfaa586c.png#clientId=u92d89d6d-6bf2-4&from=paste&height=253&id=u7b3f2b40&margin=%5Bobject%20Object%5D&name=image.png&originHeight=505&originWidth=692&originalType=binary&ratio=1&size=22271&status=done&style=none&taskId=ue4fbd917-b927-4c58-93e1-4afeea64500&width=346)
透视的阴影【透视视锥体不是标准长方体】比较奇怪，这里在附一对unity聚光灯与默认standard材质的渲染对比图（左为我们的透视阴影，右为unity聚光灯阴影）
正交相机模式：
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632583405978-ea300965-b521-4a54-8cd2-d763364c6ac3.png#clientId=u92d89d6d-6bf2-4&from=paste&height=227&id=u07b18679&margin=%5Bobject%20Object%5D&name=image.png&originHeight=506&originWidth=822&originalType=binary&ratio=1&size=33094&status=done&style=none&taskId=u2e489e80-285f-49c4-a881-b2c649df9be&width=369)![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632583492923-dd6aa415-6122-4ad2-927d-8647847667b0.png#clientId=u92d89d6d-6bf2-4&from=paste&height=144&id=u37cd2a03&margin=%5Bobject%20Object%5D&name=image.png&originHeight=263&originWidth=682&originalType=binary&ratio=1&size=21143&status=done&style=none&taskId=u22272be1-18b1-442e-93f8-2d629376c87&width=373)
透视相机模式：
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632583558369-a4c17763-3091-4047-9af5-63ae77571e22.png#clientId=u92d89d6d-6bf2-4&from=paste&height=255&id=ufc9a9e2a&margin=%5Bobject%20Object%5D&name=image.png&originHeight=510&originWidth=1556&originalType=binary&ratio=1&size=82979&status=done&style=none&taskId=uefad66ce-3d3c-43a2-b72e-7978bf18d7b&width=778)
#### 控制阴影强度
阴影如果想反映光的强度，那么我们可以给阴影一个强度因子（让他不是直接返回0），黑色代表光很强，越浅则光越弱，那么其实返回的阴影值就越大。
[![shadow_strength.mp4](https://gw.alipayobjects.com/mdn/prod_resou/afts/img/A*NNs6TKOR3isAAAAAAAAAAABkARQnAQ)]()#### 与光照混合
我们利用phong光照模型计算主颜色，之后乘以阴影颜色即可
```c
float4 ps_main (v2f i) : SV_Target {
    float4 s = shadow(i);//shadow value
    //return s;
    float4 c = basicLighting(i.wpos, i.normal);//phong color
    return c * s;
}
```
正交阴影图和透视阴影图的对比
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632584596323-80e05a5c-1a3d-4409-ab91-60003596f6a1.png#clientId=u92d89d6d-6bf2-4&from=paste&height=200&id=ud9259fee&margin=%5Bobject%20Object%5D&name=image.png&originHeight=526&originWidth=886&originalType=binary&ratio=1&size=66695&status=done&style=shadow&taskId=uffa4679c-0a9e-403a-9d17-dce666217c1&width=337)	![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632584552280-80258cb4-cead-4697-8806-d13bd6652def.png#clientId=u92d89d6d-6bf2-4&from=paste&height=200&id=uf8b2186d&margin=%5Bobject%20Object%5D&name=image.png&originHeight=520&originWidth=873&originalType=binary&ratio=1&size=69672&status=done&style=shadow&taskId=u1fe9f3b8-4ee7-4cd2-846a-a3ce9074f92&width=335.5)
### PCF
【注：此主题展示均用正交阴影图】


上面的阴影近处看非常生硬，锯齿感明显，如果希望阴影柔和一些，可以增加阴影贴图分辨率：
（512x512）对比（5120x5120）
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632585066898-cda630ab-5256-41c3-9227-7113e8824cae.png#clientId=u92d89d6d-6bf2-4&from=paste&height=98&id=uc2afbe57&margin=%5Bobject%20Object%5D&name=image.png&originHeight=546&originWidth=1915&originalType=binary&ratio=1&size=96617&status=done&style=none&taskId=u2324d324-625a-4562-8097-f2f07069844&width=343) ![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632584954257-c26879ec-f019-4d83-81fc-f576d8ba2aa7.png#clientId=u92d89d6d-6bf2-4&from=paste&height=102&id=u4bd1e485&margin=%5Bobject%20Object%5D&name=image.png&originHeight=575&originWidth=1914&originalType=binary&ratio=1&size=102503&status=done&style=none&taskId=ua298a169-9331-48e8-9b16-80238bbf391&width=339)
或是改变滤波模式
（Point）对比（Bilinear）
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632585223703-9b54f805-b095-4211-9987-d4a03aaa7e56.png#clientId=u92d89d6d-6bf2-4&from=paste&height=104&id=u741e9975&margin=%5Bobject%20Object%5D&name=image.png&originHeight=570&originWidth=1918&originalType=binary&ratio=1&size=104659&status=done&style=none&taskId=u6fdb7ce9-8d8b-4972-a0a1-7e5b1dac77a&width=350)	![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632585286357-d10fa3c7-e9bc-4c7c-bdaa-90129820a6e1.png#clientId=u92d89d6d-6bf2-4&from=paste&height=106&id=u3aa9897a&margin=%5Bobject%20Object%5D&name=image.png&originHeight=571&originWidth=1917&originalType=binary&ratio=1&size=104568&status=done&style=none&taskId=u6d99db05-60ce-4ed2-a576-88d694e1694&width=357)
但是上述方式采样方式灵活性太小且开销较大，下面介绍百分比渐进过滤（PCF）。
#### 4 tap PCF
【详情可见《DX12游戏开发实战20.4.3》】
我们不希望非0即1的结果，希望以一种合适的滤波方式产生更柔和的过渡，即0到1之间的值。
步骤是：将投影点转换到纹理空间，之后对采样点及其周围三点进行采样，对采样结果进行双线性插值。
​

![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632586276108-5e1a9205-4efd-4bc9-8518-70d91f76f8bd.png#clientId=u92d89d6d-6bf2-4&from=paste&height=263&id=u5fcc3aac&margin=%5Bobject%20Object%5D&name=image.png&originHeight=525&originWidth=628&originalType=binary&ratio=1&size=36946&status=done&style=none&taskId=ueb7628b6-962a-495c-9681-3ea4eeea6c6&width=314)
```c
//refer:《DX12开发实战》20章阴影贴图 & https://www.youtube.com/watch?v=3AdLu0PHOnE&t=413s
float tap4PCF(float d,float2 uv)
{
    // Transform to texel space
    float2 texPos = _TexSize*uv.xy;
    // Determine the lerp amounts.    
    float2 t = frac(texPos);
    // sample shadow map
    float dx = 1.0f/_TexSize;
    float s0 = tex2D(MyShadowMap, uv).r;
    float s1 = tex2D(MyShadowMap, uv+float2(dx,0)).r;
    float s2 = tex2D(MyShadowMap, uv+float2(0,dx)).r;
    float s3 = tex2D(MyShadowMap, uv+float2(dx,dx)).r;
    float result0 = shadowMap(d,s0);
    float result1 = shadowMap(d,s1);
    float result2 = shadowMap(d,s2);
    float result3 = shadowMap(d,s3);

    float shadow = lerp( lerp( result0, result1, t.x ), lerp( result2, result3, t.x ), t.y );
    return shadow;
}
```
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632586405587-83de66d9-5702-4f9c-9f4f-4348cb45f04b.png#clientId=u92d89d6d-6bf2-4&from=paste&height=153&id=u670c5e93&margin=%5Bobject%20Object%5D&name=image.png&originHeight=521&originWidth=1206&originalType=binary&ratio=1&size=50432&status=done&style=shadow&taskId=u135dd7e3-714c-42e4-8189-f0de9bfc92b&width=354)	![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632586336115-a555ff1b-1b6e-47da-bc9f-c9e3945bdd40.png#clientId=u92d89d6d-6bf2-4&from=paste&height=151&id=u357d1509&margin=%5Bobject%20Object%5D&name=image.png&originHeight=524&originWidth=1211&originalType=binary&ratio=1&size=109989&status=done&style=shadow&taskId=u153caa0f-ff49-4448-8b65-606e98616ac&width=349.5)
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632587326102-f40a67d1-1292-4f1f-a592-3e0428bc31b8.png#clientId=u92d89d6d-6bf2-4&from=paste&height=146&id=VUTuT&margin=%5Bobject%20Object%5D&name=image.png&originHeight=511&originWidth=1286&originalType=binary&ratio=1&size=105377&status=done&style=none&taskId=u319ae2d8-da86-40b3-8584-e49d5839847&width=367)![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632587520849-fa8f8c56-bb0b-4ba0-99c5-b73a3c6a5348.png#clientId=u92d89d6d-6bf2-4&from=paste&height=147&id=uea1e4bbc&margin=%5Bobject%20Object%5D&name=image.png&originHeight=513&originWidth=1289&originalType=binary&ratio=1&size=147377&status=done&style=none&taskId=uc2e4c7fe-611f-4139-8667-e5659833f7c&width=368.5)
#### 3X3 BOX FILTER
```c
float PCF_Filter(float d,float2 uv)
{
    //PCF
    float shadow = 0;
    float dx = 1.0f/_TexSize;
    for(int x = -1;x<=1;++x)
        for(int y=-1;y<=1;++y)
        {
            float2 _offset = dx*float2(x,y);
            float m = tex2D(MyShadowMap,uv+_offset).r;
            if(_tap4)
                shadow += tap4PCF(d,uv+_offset);							
            else
                shadow += shadowMap(d,m);
        }		
    return shadow/9.0f;
}
```
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632586405587-83de66d9-5702-4f9c-9f4f-4348cb45f04b.png#clientId=u92d89d6d-6bf2-4&from=paste&height=153&id=I183O&margin=%5Bobject%20Object%5D&name=image.png&originHeight=521&originWidth=1206&originalType=binary&ratio=1&size=50432&status=done&style=shadow&taskId=u135dd7e3-714c-42e4-8189-f0de9bfc92b&width=354)	![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632586471942-20168825-aae9-470e-899e-bd3a0af6c13e.png#clientId=u92d89d6d-6bf2-4&from=paste&height=156&id=ub467c733&margin=%5Bobject%20Object%5D&name=image.png&originHeight=518&originWidth=1204&originalType=binary&ratio=1&size=157247&status=done&style=shadow&taskId=uef7e6b66-4424-42c0-b50a-4a401d6601f&width=363)
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632587326102-f40a67d1-1292-4f1f-a592-3e0428bc31b8.png#clientId=u92d89d6d-6bf2-4&from=paste&height=146&id=ud20d3827&margin=%5Bobject%20Object%5D&name=image.png&originHeight=511&originWidth=1286&originalType=binary&ratio=1&size=105377&status=done&style=none&taskId=u319ae2d8-da86-40b3-8584-e49d5839847&width=367)![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632587307099-2700e9c2-6920-4b03-8e91-567a4cf8d9b4.png#clientId=u92d89d6d-6bf2-4&from=paste&height=148&id=ud91281dc&margin=%5Bobject%20Object%5D&name=image.png&originHeight=514&originWidth=1217&originalType=binary&ratio=1&size=189506&status=done&style=none&taskId=u6877f5b2-2823-48ba-98cc-fa24f7984b8&width=350)
[![rotate.mp4](https://gw.alipayobjects.com/mdn/prod_resou/afts/img/A*NNs6TKOR3isAAAAAAAAAAABkARQnAQ)]()

注：过大的PCF滤波核通常不会有满意的效果，因为纹素之间的区域和场景区域并不相同，误差可能随着滤波核的增大被放大。【详见《DX12游戏开发实战20.5》】
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632586164198-8b87c417-2f62-4137-ab1f-8045a3e3ce78.png#clientId=u92d89d6d-6bf2-4&from=paste&height=192&id=uaab5d5af&margin=%5Bobject%20Object%5D&name=image.png&originHeight=383&originWidth=630&originalType=binary&ratio=1&size=61966&status=done&style=none&taskId=u3d3b82c2-73f3-406b-b9af-84df804cba5&width=315)
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632587180795-00bb1534-f581-40e3-ad0b-ef9f2dc1af08.png#clientId=u92d89d6d-6bf2-4&from=paste&height=286&id=ue3b46d6b&margin=%5Bobject%20Object%5D&name=image.png&originHeight=571&originWidth=1380&originalType=binary&ratio=1&size=132672&status=done&style=none&taskId=u7f681085-bcef-4fcd-a94e-3ada1e1292e&width=690)
通过增加偏移值解决
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632587225794-0585e2bd-220b-450c-8496-440c66bcc909.png#clientId=u92d89d6d-6bf2-4&from=paste&height=265&id=u224dcc4a&margin=%5Bobject%20Object%5D&name=image.png&originHeight=530&originWidth=1718&originalType=binary&ratio=1&size=144437&status=done&style=none&taskId=ufcd2ccd7-0a17-4a4b-8668-ef908b929c0&width=859)
#### 总对比
（左至右：shadow map；4 tap pcf；box filter 3X3 pcf）
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632628421125-976784d0-3096-4fea-8ebf-d419a6ee39b2.png#clientId=u8248dedc-f94e-4&from=paste&height=124&id=Zt1Yy&margin=%5Bobject%20Object%5D&name=image.png&originHeight=1941&originWidth=3822&originalType=binary&ratio=1&size=1540495&status=done&style=none&taskId=ud44ad895-421c-495a-b8fb-48909e6c51f&width=245)![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632628363124-8a221c9a-cd3c-4c58-a3cb-b038ff171281.png#clientId=u8248dedc-f94e-4&from=paste&height=124&id=u33ee7fa9&margin=%5Bobject%20Object%5D&name=image.png&originHeight=1934&originWidth=3823&originalType=binary&ratio=1&size=1531740&status=done&style=none&taskId=u50e134dc-3d37-4afe-81fa-59004d8f483&width=245)![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632628317629-0c08e0ee-570e-4d3e-a8d1-57d633950797.png#clientId=u8248dedc-f94e-4&from=paste&height=124&id=u79fe19ec&margin=%5Bobject%20Object%5D&name=image.png&originHeight=1940&originWidth=3832&originalType=binary&ratio=1&size=2404709&status=done&style=none&taskId=uaad990a8-8333-4414-91fa-9fd7dd32125&width=245)

| shadow map | 4 tap pcf | box filter 3X3 pcf |
| --- | --- | --- |
| 当前像素深度和shadow map深度比较 | 定位当前shadow map中4个纹素和当前像素深度进行比较 | 3X3滤波核在shadowmap上采样 |
|  | 对比较结果双线性插值 | 对每个样本执行4 tap pcf或shadow map |



## Unity阴影系统
没有灯光的场景：
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632634619244-90d7af5b-a81f-43b7-b971-5d232def6478.png#clientId=u72eaf293-bf93-4&from=paste&height=261&id=udd9aaa2f&margin=%5Bobject%20Object%5D&name=image.png&originHeight=521&originWidth=1321&originalType=binary&ratio=1&size=95429&status=done&style=none&taskId=u6a4e9cf9-0068-4d10-8a2b-798d65fd239&width=660.5)
### directional light
场景里有两束平行光，渲染场景如下：
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632634872308-5468ec5f-3915-4842-9ba9-c3a6e96ad6b1.png#clientId=u72eaf293-bf93-4&from=paste&height=262&id=uca431dec&margin=%5Bobject%20Object%5D&name=image.png&originHeight=523&originWidth=1322&originalType=binary&ratio=1&size=107989&status=done&style=none&taskId=u63e3aad6-0ca7-4970-a643-ee1fc694ab1&width=661)
#### 渲染流程
每一束光会渲染自己的场景深度图（shadow map）,然后生成屏幕空间阴影图（screen space shadow map），之后渲染光照时采样上述阴影图，与其中颜色相乘得到最终渲染图
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632636782397-07b0bf69-976e-44b3-ac3b-86235e8c84da.png#clientId=u72eaf293-bf93-4&from=paste&height=94&id=ue529fe7c&margin=%5Bobject%20Object%5D&name=image.png&originHeight=147&originWidth=408&originalType=binary&ratio=1&size=12523&status=done&style=none&taskId=ua33d8404-e260-413d-8f44-899893ac0e3&width=262)![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632634967761-84661ba9-b9cf-42d7-9e1e-34fee1fa67a1.png#clientId=u72eaf293-bf93-4&from=paste&height=94&id=ArJrv&margin=%5Bobject%20Object%5D&name=image.png&originHeight=188&originWidth=520&originalType=binary&ratio=1&size=23198&status=done&style=none&taskId=u98d0099f-c453-4a41-88fb-40b2659220a&width=260)


第一束光的深度图和其对应的屏幕空间阴影图（stable fit）
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632636920689-5de643c5-5b36-428b-ac54-6c0ff08d270d.png#clientId=u72eaf293-bf93-4&from=paste&height=206&id=u51edd19c&margin=%5Bobject%20Object%5D&name=image.png&originHeight=518&originWidth=519&originalType=binary&ratio=1&size=9465&status=done&style=none&taskId=u1f131513-c770-4cfa-b9ad-7de6131dd55&width=206.5)![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632636961091-64eacf99-5574-4fcb-aa90-b51f400a304f.png#clientId=u72eaf293-bf93-4&from=paste&height=206&id=u9bc8e803&margin=%5Bobject%20Object%5D&name=image.png&originHeight=515&originWidth=1124&originalType=binary&ratio=1&size=100401&status=done&style=none&taskId=u1d4b80d5-7439-4ede-9d29-6e7c68bac02&width=450)
​

第二束光的深度图和其对应的屏幕空间阴影图（stable fit）
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632636977551-df3fd009-b760-4cad-8cf0-1f831a4ca79f.png#clientId=u72eaf293-bf93-4&from=paste&height=205&id=ua32315b6&margin=%5Bobject%20Object%5D&name=image.png&originHeight=518&originWidth=519&originalType=binary&ratio=1&size=9185&status=done&style=none&taskId=u34224f42-9f2d-4abb-8f74-f05c193cb08&width=205.5)![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632636998540-b2a1304f-bc19-464b-8977-0f0485465b03.png#clientId=u72eaf293-bf93-4&from=paste&height=206&id=ub13a4c4b&margin=%5Bobject%20Object%5D&name=image.png&originHeight=521&originWidth=1119&originalType=binary&ratio=1&size=111781&status=done&style=none&taskId=u75e6fbc6-ff32-414e-8e82-739a5b6232d&width=442.5)


#### 阴影级联
由于深度图（shadow map）分辨率有限，且一般光源都是倾斜于场景的，不同深度的采样精度也会不一样，阴影级联类似Mipmip，也是一种分层级的技术，离较远的阴影最终渲染到较小的屏幕区域，更加有效地使用了纹理像素。不利的一面是，场景会多渲染三遍。
close fit/stable fit:
级联带的形状取决于Shadow Projection质量设置。默认值为“Stable Fit”。在此模式下，根据到相机位置的距离选择频段。另一个选项是“Close Fit”，它改用相机的深度。这会在相机的视线方向上产生矩形带。
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632635932741-b19f5d9f-e5a6-4705-9982-1cf1d625775d.png#clientId=u72eaf293-bf93-4&from=paste&height=161&id=u6774077b&margin=%5Bobject%20Object%5D&name=image.png&originHeight=501&originWidth=1117&originalType=binary&ratio=1&size=166704&status=done&style=shadow&taskId=u0db12ef7-cad9-4af0-9ac7-a60a6c66bfc&width=359)![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632635950500-c70dc574-bce1-451a-a91d-f22e69f0dcfc.png#clientId=u72eaf293-bf93-4&from=paste&height=161&id=u82f5f69a&margin=%5Bobject%20Object%5D&name=image.png&originHeight=518&originWidth=1127&originalType=binary&ratio=1&size=178048&status=done&style=shadow&taskId=u640b1ab7-6473-4895-92d9-a801ceef066&width=350)
第一束光的深度图和其对应的屏幕空间阴影图（Four Cascades+stable fit）
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632637499716-e53701ff-7660-4f70-8f3c-e5c9ec041ecd.png#clientId=u72eaf293-bf93-4&from=paste&height=209&id=ube4f79ee&margin=%5Bobject%20Object%5D&name=image.png&originHeight=525&originWidth=520&originalType=binary&ratio=1&size=22624&status=done&style=shadow&taskId=u1ce82ccd-69ca-4698-9dcc-5dfabd245a7&width=207)![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632637514881-bafa9173-a7e8-4ef6-aaae-bfc7ef9e5b95.png#clientId=u72eaf293-bf93-4&from=paste&height=188&id=u51a0324c&margin=%5Bobject%20Object%5D&name=image.png&originHeight=516&originWidth=1125&originalType=binary&ratio=1&size=44791&status=done&style=shadow&taskId=u51b9fd88-1106-4919-b623-6b8de164278&width=410.5)
​

第二束光的深度图和其对应的屏幕空间阴影图（Four Cascades+stable fit）
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632637528168-20b3aab2-d367-4f7e-b58b-596c2d9c3085.png#clientId=u72eaf293-bf93-4&from=paste&height=206&id=u1adbccc7&margin=%5Bobject%20Object%5D&name=image.png&originHeight=519&originWidth=519&originalType=binary&ratio=1&size=19548&status=done&style=shadow&taskId=u7eb1135e-5a75-4629-a4cb-237091c1abb&width=205.5)![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632637541366-5a6f749d-b023-4245-bded-5c9d3869e85a.png#clientId=u72eaf293-bf93-4&from=paste&height=197&id=ufcae2538&margin=%5Bobject%20Object%5D&name=image.png&originHeight=521&originWidth=1127&originalType=binary&ratio=1&size=52665&status=done&style=shadow&taskId=udac3aeb9-e30d-417c-8e5f-761c2809969&width=426.5)
注：聚光灯和点光源有实际位置且光线不平行，不支持级联。
### spot light
场景里有两束聚光灯，渲染场景如下：
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632637958510-337484d2-7864-4ab5-85fa-6ad63efed071.png#clientId=u91023410-eda1-4&from=paste&height=173&id=ubd26f923&margin=%5Bobject%20Object%5D&name=image.png&originHeight=520&originWidth=1122&originalType=binary&ratio=1&size=81280&status=done&style=none&taskId=ua26d9116-0511-44bc-bde6-a97eaf149e5&width=374)
#### 渲染流程：
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632638349553-d09b8e7d-ebfa-4fa5-a793-28263b7a3b90.png#clientId=u91023410-eda1-4&from=paste&height=138&id=ubc36dfe9&margin=%5Bobject%20Object%5D&name=image.png&originHeight=253&originWidth=412&originalType=binary&ratio=1&size=26199&status=done&style=none&taskId=u32867f54-e685-4ba1-b0e3-2ec005b8289&width=224.3312530517578)
聚光灯具有实际位置，并且光线不平行。聚光灯的摄像机具有透视图。两盏灯在不同位置，其渲染的深度图大小也相同。
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632638181870-63620ef6-5bfc-42b8-88a8-ef34ea58bd48.png#clientId=u91023410-eda1-4&from=paste&height=112&id=ue6d7742e&margin=%5Bobject%20Object%5D&name=image.png&originHeight=255&originWidth=253&originalType=binary&ratio=1&size=26215&status=done&style=none&taskId=udd755bec-4766-4f4b-aac6-decbbd87a40&width=111.33125305175781)![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632638218386-f8b7faee-0d80-4667-8049-e457670e1880.png#clientId=u91023410-eda1-4&from=paste&height=175&id=u76d08b86&margin=%5Bobject%20Object%5D&name=image.png&originHeight=525&originWidth=521&originalType=binary&ratio=1&size=65585&status=done&style=none&taskId=u74650915-55ae-494c-bab6-270958f0be4&width=173.66666666666666)
### point light
场景里有两点光源，渲染场景如下：
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632638514619-fb6e5729-f95a-41a7-a653-798e310a778f.png#clientId=u91023410-eda1-4&from=paste&height=174&id=u24857362&margin=%5Bobject%20Object%5D&name=image.png&originHeight=522&originWidth=1123&originalType=binary&ratio=1&size=94310&status=done&style=none&taskId=u79360244-a03a-4c35-8d7d-c416c83c0f0&width=374.3333333333333)
#### 渲染流程
阴影贴图必须是立方体贴图。通过在相机指向六个不同方向的情况下渲染场景来创建立方体贴图，每个立方体的每个面一次。因此，点光源的阴影非常昂贵。
(这里有个疑问：一盏点光是6个shadow.renderjob，两盏是11个renderjob,三盏是16个，也许unity这里优化合并了一些【个人观点】)
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632638875858-5e7dcaee-2ab8-4678-8ba0-1f4c77f7d92f.png#clientId=u91023410-eda1-4&from=paste&height=215&id=ud1c65d38&margin=%5Bobject%20Object%5D&name=image.png&originHeight=646&originWidth=420&originalType=binary&ratio=1&size=68374&status=done&style=none&taskId=udf583292-2e36-410d-9868-2d3a6089abf&width=140)
一盏点光对应的六张阴影图：
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632640092045-4e04fe10-664d-404b-9fcb-cb3529dc88c7.png#clientId=u91023410-eda1-4&from=paste&height=225&id=u539faa0c&margin=%5Bobject%20Object%5D&name=image.png&originHeight=1015&originWidth=1013&originalType=binary&ratio=1&size=39663&status=done&style=none&taskId=u5a901a31-fc9e-4bdc-81bb-1ff4153510d&width=225)![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632640105837-8ecee312-a379-4905-811c-ed961c1ecead.png#clientId=u91023410-eda1-4&from=paste&height=225&id=u8d62681b&margin=%5Bobject%20Object%5D&name=image.png&originHeight=1019&originWidth=1017&originalType=binary&ratio=1&size=59807&status=done&style=none&taskId=u11a467b8-963d-4ed3-a837-0d7fee0df63&width=225)![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632640120620-56fd9ab7-6967-4c7d-8a36-6ee87b5ac67d.png#clientId=u91023410-eda1-4&from=paste&height=225&id=ub2b9cd28&margin=%5Bobject%20Object%5D&name=image.png&originHeight=1012&originWidth=1014&originalType=binary&ratio=1&size=22847&status=done&style=none&taskId=u4fb9496c-3973-49db-904b-0d6701b1530&width=225)
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632640133950-77b1fec1-bb46-46eb-9f85-082cfc1fee3d.png#clientId=u91023410-eda1-4&from=paste&height=224&id=u3680a93e&margin=%5Bobject%20Object%5D&name=image.png&originHeight=1009&originWidth=1013&originalType=binary&ratio=1&size=43037&status=done&style=none&taskId=ue6a4991e-0acd-40bb-8ac1-e3122584a03&width=225)![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632640148007-d5f105e8-e806-4a13-be60-79a5c359b172.png#clientId=u91023410-eda1-4&from=paste&height=224&id=u7a96aeab&margin=%5Bobject%20Object%5D&name=image.png&originHeight=1013&originWidth=1017&originalType=binary&ratio=1&size=66335&status=done&style=none&taskId=u886e1bc4-a4a5-4c8e-b74c-dd1b7bcd613&width=225)![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632640162766-516ab634-7fbd-498a-ac88-fbabc2a861c0.png#clientId=u91023410-eda1-4&from=paste&height=225&id=u16a0d453&margin=%5Bobject%20Object%5D&name=image.png&originHeight=1015&originWidth=1016&originalType=binary&ratio=1&size=58292&status=done&style=none&taskId=u6a733891-7764-4260-8c33-b005bcb1c35&width=225)
### 三种灯光的对比
|  | 平行光 | 聚光灯 | 点光 |
| --- | --- | --- | --- |
| 支持屏幕空间阴影图 | 是 | 否 | 否 |
| 深度图投影模式 | 正交 | 透视 | 透视 |
| 是否支持级联 | 是 | 否 | 否 |
| 采样深度图数量 | 一张或若干（根据级联数） | 一张 | 六张 |

## Unity Projector
在移动端，实时阴影的计算开销十分昂贵，而unity projector组件可以制造一种假阴影（fake shadow），具体原理就是老师一开始所讲的**投影阴影。**
下面的图片记录了unity projector的应用，场景中静态物体接受灯光（或者烘焙），动态人物利用projector提供假阴影。（projector在非平面情况下情况就不太好了）
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632652156843-59f2e125-227e-4d95-a272-dbc5105cbbdc.png#clientId=u3d6d44b0-7d5c-4&from=paste&height=209&id=u4d0e67cb&margin=%5Bobject%20Object%5D&name=image.png&originHeight=616&originWidth=1013&originalType=binary&ratio=1&size=63551&status=done&style=shadow&taskId=ud972ce92-b893-4e58-a723-b41cc6f02e7&width=343.5)![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632652213695-e527ff8a-0315-4ea3-a817-677c762249f3.png#clientId=u3d6d44b0-7d5c-4&from=paste&height=215&id=uea1aaf56&margin=%5Bobject%20Object%5D&name=image.png&originHeight=837&originWidth=1555&originalType=binary&ratio=1&size=130268&status=done&style=shadow&taskId=ub6a6eca6-a313-4cf9-b504-b6d65a009a9&width=399)
![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632652675873-1cc5ab95-972f-4f6a-953d-ce036789022c.png#clientId=uf8925e94-e859-4&from=paste&height=183&id=u68c70e65&margin=%5Bobject%20Object%5D&name=image.png&originHeight=629&originWidth=1267&originalType=binary&ratio=1&size=100674&status=done&style=shadow&taskId=ub8fab853-f246-4a46-ac52-6f62682cb46&width=369.5)![image.png](https://cdn.nlark.com/yuque/0/2021/png/22095277/1632652773362-49a51f3c-02e3-4208-99ca-d428848ccc48.png#clientId=uf8925e94-e859-4&from=paste&height=188&id=u3ec6c706&margin=%5Bobject%20Object%5D&name=image.png&originHeight=1017&originWidth=1912&originalType=binary&ratio=1&size=453144&status=done&style=shadow&taskId=u35051c7f-986f-4ad2-876c-defde53bad6&width=354)
[![projector.mp4](https://gw.alipayobjects.com/mdn/prod_resou/afts/img/A*NNs6TKOR3isAAAAAAAAAAABkARQnAQ)]()

## 参考


[Unity Shadow Mapping Demo](https://www.youtube.com/watch?v=3AdLu0PHOnE)


[金柚子大佬 · 语雀 (yuque.com)](https://www.yuque.com/yikejinyouzi/aau4tk/totr2w#Bi0nv)


[Shadow Map (廣東話, Cantonese) [簡單黎講 C++]](https://www.youtube.com/watch?v=oPxY1eTrrOo)


[Unity Shader - Custom SSSM(Screen Space Shadow Map) 自定义屏幕空间阴影图](https://blog.csdn.net/linjf520/article/details/105456097)


[Unity Shader - Custom DirectionalLight ShadowMap 自定义方向光的ShadowMap](https://blog.csdn.net/linjf520/article/details/105401157)


[Unity实时阴影实现——Shadow Mapping](https://zhuanlan.zhihu.com/p/45653702)


[游戏里的动态阴影-ShadowMap实现原理](https://www.cnblogs.com/lijiajia/p/7231605.html)


[Unity Shader - 获取BuiltIn深度纹理和自定义深度纹理的数据](https://blog.csdn.net/linjf520/article/details/104723859)


[Unity Blob Shadow Projector](https://www.youtube.com/watch?v=hQcZA3dYGxg)
​

[基础渲染系列（七）——阴影](https://zhuanlan.zhihu.com/p/144271158)
​

《DX12游戏开发实战》第20章阴影贴图
