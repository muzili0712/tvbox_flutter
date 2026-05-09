import React, {useEffect} from 'react';
import { createRoot } from 'react-dom/client';
import {Button, Card, Form, Input, Tabs, message, Divider} from 'antd';
import axios from 'axios'
import copy from 'copy-to-clipboard';
import './App.less'
import refreshImg from './assets/qrcode_refresh.jpg'

const { TabPane } = Tabs;

const http = axios.create({
  baseURL: '/website',
})

http.interceptors.response.use(function (response) {
  if (response.data.code !== 0) {
    message.error(response.data.message);
    throw new Error(response.data);
  } else {
    return response.data.data;
  }
}, function (error) {
  return Promise.reject(error);
});

message.config({
  top: '40%',
});

function QrcodeImage({src}) {
  const [inited, setInited] = React.useState(false);
  return (
    <img src={inited ? src : refreshImg} onClick={() => setInited(true)}/>
  )
}

function App() {
  const [quarkCookie, setQuarkCookie] = React.useState('');
  const [ucCookie, setUcCookie] = React.useState('');
  const [ucToken, setUcToken] = React.useState('');

  const generateQuarkCookie = async () => {
    const cookie = await http.post('/quark/cookie')
    setQuarkCookie(cookie)
  }

  const storeQuarkCookie = async () => {
    await http.put('/quark/cookie', {
      cookie: quarkCookie,
    })
    message.success('写入成功')
  }

  const generateUcCookie = async () => {
    const cookie = await http.post('/uc/cookie')
    setUcCookie(cookie)
  }

  const storeUcCookie = async () => {
    await http.put('/uc/cookie', {
      cookie: ucCookie,
    })
    message.success('写入成功')
  }

  const generateUcToken = async () => {
    const token = await http.post('/uc-tv/token')
    setUcToken(token)
  }

  const storeUcToken = async () => {
    await http.put('/uc-tv/token', {
      cookie: ucToken,
    })
    message.success('写入成功')
  }

  const copyText = (text) => {
    copy(text)
    message.success('复制成功')
  }

  useEffect(() => {
    http.get('/quark/cookie')
      .then(data => {
        setQuarkCookie(data);
      })
    http.get('/uc/cookie')
      .then(data => {
        setUcCookie(data);
      })
    http.get('/uc-tv/token')
      .then(data => {
        setUcToken(data);
      })
  }, []);

  return (
    <div className={'container'}>
      <Card style={{ minHeight: 500 }}>
        <Tabs defaultActiveKey={'quark'} onChange={console.log}>
          <TabPane tab="夸克" key="quark">
            <div className={'qrcodeCard'}>
              <QrcodeImage src="/website/quark/qrcode"/>
              <Divider>
                <Button onClick={generateQuarkCookie}>扫码后点我</Button>
              </Divider>
              <Input.TextArea value={quarkCookie} readOnly={true} rows={4}/>
              <div className={'btns'}>
                <Button onClick={() => copyText(quarkCookie)} disabled={!quarkCookie} color="cyan" variant="solid" style={{marginRight: 24}} size={'large'}>复制</Button>
                <Button onClick={storeQuarkCookie} disabled={!quarkCookie} type={'primary'} size={'large'}>入库</Button>
              </div>
            </div>
          </TabPane>
          <TabPane tab="UC Cookie" key="uc-cookie">
            <div className={'qrcodeCard'}>
              <QrcodeImage src="/website/uc/qrcode"/>
              <Divider>
                <Button onClick={generateUcCookie}>扫码后点我</Button>
              </Divider>
              <Input.TextArea value={ucCookie} readOnly={true} rows={4}/>
              <div className={'btns'}>
                <Button onClick={() => copyText(ucCookie)} disabled={!ucCookie} color="cyan" variant="solid"
                        style={{marginRight: 24}} size={'large'}>复制</Button>
                <Button onClick={storeUcCookie} disabled={!ucCookie} type={'primary'} size={'large'}>入库</Button>
              </div>
            </div>
          </TabPane>
          <TabPane tab="UC token" key="uc-token">
            <div className={'qrcodeCard'}>
              <QrcodeImage src="/website/uc-tv/qrcode"/>
              <Divider>
                <Button onClick={generateUcToken}>扫码后点我</Button>
              </Divider>
              <Input.TextArea value={ucToken} readOnly={true} rows={4}/>
              <div className={'btns'}>
                <Button onClick={() => copyText(ucToken)} disabled={!ucToken} color="cyan" variant="solid"
                        style={{marginRight: 24}} size={'large'}>复制</Button>
                <Button onClick={storeUcToken} disabled={!ucToken} type={'primary'} size={'large'}>入库</Button>
              </div>
            </div>
          </TabPane>
          <TabPane tab="天翼" key="tianyi">
            <Form>
              <Form.Item label={"账号"}>
                <Input/>
              </Form.Item>
              <Form.Item label={"密码"}>
                <Input/>
              </Form.Item>
            </Form>
          </TabPane>
          <TabPane tab="移动" key="yidong">
            移动
          </TabPane>
        </Tabs>
      </Card>
    </div>
  )
}

export function renderClient() {
  const root = createRoot(document.getElementById('app'));
  root.render(<App/>);
}