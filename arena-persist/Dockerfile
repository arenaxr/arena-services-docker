FROM node

WORKDIR /home/node/app

#copy app files into container
COPY . .

RUN npm install

CMD [ "node", "server.js" ]
